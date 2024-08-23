import { chromium } from 'playwright';
import jsforce from 'jsforce';
import CheckoutPage from '../playwright/pages/CheckoutPageSFRA6.mjs';
import { Cards } from '../playwright/paymentFlows/cards.mjs';
import { ShopperData } from '../playwright/data/shopperData.mjs';
import { CardData } from '../playwright/data/cardData.mjs';

const shopperData = new ShopperData();
const cardData = new CardData();
const maxPollAttempts = process.env.MAX_POLL_ATTEMPTS;
let sfConnection;
let checkoutPage;
let cards;
const baseURL = `https://${process.env.SFCC_HOSTNAME}`;

beforeAll(async () => {
  sfConnection = new jsforce.Connection({
    loginUrl: 'https://login.salesforce.com',
  });
  await sfConnection.login(
    process.env.SALESFORCE_USERNAME,
    process.env.SALESFORCE_PASSWORD
  );
});

describe('E2E Order Creation and Payment Capture', () => {
  let orderNumber;

  beforeAll(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      httpCredentials: {
        username: process.env.SFCC_STOREFRONT_USERNAME,
        password: process.env.SFCC_STOREFRONT_PASSWORD,
      },
    });
    const page = await context.newPage();
    checkoutPage = new CheckoutPage(page);
    cards = new Cards(page);

    await page.goto(`${baseURL}/s/RefArch/home`);
    await checkoutPage.goToCheckoutPageWithFullCart('US', 1);
    await checkoutPage.setShopperDetails(shopperData.US);
    await cards.doCardPayment(cardData.noThreeDs);
    await checkoutPage.completeCheckout();
    await checkoutPage.expectSuccess();

    const orderNumberElement = await page.locator('span.summary-details.order-number');
    const orderNumberElementContent = await orderNumberElement.textContent();

    orderNumber = orderNumberElementContent.trim();

    await browser.close();
  }, 90000);

  test('should create a fulfillment order, invoice, and capture payment', async () => {
    const orderSummaryRecords = await pollOrderSummary(orderNumber, maxPollAttempts);
    expect(orderSummaryRecords.length).toBe(1);
    const orderSummaryId = orderSummaryRecords[0].Id;

    // Create fulfillment order
    const flowName = 'Create_Fulfillment_Orders';
    const flowInputParams = {
      inputs: [{ OrderSummaryId: orderSummaryId }],
    };

    await sfConnection.request({
      method: 'POST',
      url: `/services/data/v58.0/actions/custom/flow/${flowName}`,
      body: JSON.stringify(flowInputParams),
      headers: {
        'content-type': 'application/json',
      },
    });

    const fulfillmentOrderQueryResult = await sfConnection.query(
      `SELECT Id from FulfillmentOrder where OrderSummaryId = '${orderSummaryId}'`
    );
    expect(fulfillmentOrderQueryResult.records.length).toBe(1);
    const fulfillmentOrderId = fulfillmentOrderQueryResult.records[0].Id;

    // Create invoice
    const invoiceRequestBody = {};
    const createInvoiceResponse = await sfConnection.request({
      method: 'POST',
      url: `/services/data/v58.0/commerce/fulfillment/fulfillment-orders/${fulfillmentOrderId}/actions/create-invoice`,
      body: JSON.stringify(invoiceRequestBody),
      headers: {
        'content-type': 'application/json',
      },
    });
    const invoiceId = createInvoiceResponse.invoiceId;

    // Capture funds for invoice
    const captureFundRequestBody = { invoiceId };
    const captureFundResponse = await sfConnection.request({
      method: 'POST',
      url: `/services/data/v58.0/commerce/order-management/order-summaries/${orderSummaryId}/async-actions/ensure-funds-async`,
      body: JSON.stringify(captureFundRequestBody),
      headers: {
        'content-type': 'application/json',
      },
    });

    const captureReceivedLogs = await pollPaymentGatewayLog(orderSummaryId, '[capture-received]', maxPollAttempts);
    expect(captureReceivedLogs.length).toBe(1);
    const captureCompleteLogs = await pollPaymentGatewayLog(orderSummaryId, '[capture-complete]', maxPollAttempts);
    expect(captureCompleteLogs.length).toBe(1);
  });

  async function pollOrderSummary(orderNumber, maxPollAttempts) {
    const retryDelay = 5000;
    let retryCount = 0;
    let orderSummaryQueryResult;

    while (retryCount < maxPollAttempts) {
      orderSummaryQueryResult = await sfConnection.query(
        `SELECT Id FROM OrderSummary WHERE OrderNumber = '${orderNumber}'`
      );
      if (orderSummaryQueryResult.records.length > 0) {
        break;
      }
      retryCount++;
      await new Promise((resolve) => setTimeout(resolve, retryDelay));
    }

    return orderSummaryQueryResult.records;
  }

  async function pollPaymentGatewayLog(orderSummaryId, gatewayMessage, maxPollAttempts) {
    const retryDelay = 5000;
    let retryCount = 0;
    let gatewayLogQueryResult;

    while (retryCount < maxPollAttempts) {
      gatewayLogQueryResult = await sfConnection.query(
        `SELECT Id, GatewayMessage FROM PaymentGatewayLog WHERE OrderPaymentSummary.OrderSummaryId = '${orderSummaryId}' AND GatewayMessage = '${gatewayMessage}'`
      );
      if (gatewayLogQueryResult.records.length > 0) {
        break;
      }
      retryCount++;
      await new Promise((resolve) => setTimeout(resolve, retryDelay));
    }
    return gatewayLogQueryResult.records;
  }
});
