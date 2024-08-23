import { expect } from '@playwright/test';
export default class CheckoutPageSFRA {
  constructor(page) {
    this.baseURL = `https://${process.env.SFCC_HOSTNAME}`;
    this.page = page;
    this.consentButton = page.locator('.affirm');
    this.addToCartButton = page.locator('.add-to-cart');
    this.successMessage = page.locator('.add-to-cart-messages');
    this.selectQuantity = page.locator('.quantity-select');
    this.checkoutUrl =
      `${this.baseURL}on/demandware.store/Sites-RefArch-Site/fr_FR/Checkout-Login`;
    this.checkoutGuest = page.locator('.submit-customer');
    this.emailInput = page.locator('#email');
    this.customerInfoSection = page.locator('.customer-label');
    this.checkoutPageUserEmailInput = page.locator('#email-guest');
    this.checkoutPageUserFirstNameInput = page.locator(
      '#shippingFirstNamedefault',
    );
    this.checkoutPageUserLastNameInput = page.locator(
      '#shippingLastNamedefault',
    );
    this.checkoutPageUserStreetInput = page.locator(
      '#shippingAddressOnedefault',
    );
    this.checkoutPageUserHouseNumberInput = page.locator(
      '#shippingAddressTwodefault',
    );
    this.checkoutPageUserCityInput = page.locator(
      '#shippingAddressCitydefault',
    );
    this.checkoutPageUserPostCodeInput = page.locator(
      '#shippingZipCodedefault',
    );
    this.checkoutPageUserCountrySelect = page.locator(
      '#shippingCountrydefault',
    );
    this.checkoutPageUserStateSelect = page.locator('#shippingStatedefault');
    this.checkoutPageUserTelephoneInput = page.locator(
      '#shippingPhoneNumberdefault',
    );
    this.shippingSubmit = page.locator("button[value='submit-shipping']");
    this.submitPaymentButton = page.locator("button[value='submit-payment']");
    this.placeOrderButton = page.locator("button[value='place-order']");
    this.thankYouMessage = page.locator('.order-thank-you-msg');
  }

  navigateToCheckout = async (locale) => {
    await this.page.goto(this.getCheckoutUrl(locale));
  };

  goToCheckoutPageWithFullCart = async (locale, itemCount = 1) => {
    await this.addProductToCart(locale, itemCount);
    await this.successMessage.waitFor({ visible: true, timeout: 20000 });

    await this.navigateToCheckout(locale);
    await this.setEmail();
    await this.checkoutGuest.click();
  };

  getCheckoutUrl(locale) {
    return `${this.baseURL}/on/demandware.store/Sites-RefArch-Site/${locale}/Checkout-Begin`;
  }

  addProductToCart = async (locale, itemCount = 1) => {
    await this.consentButton.click();
    await this.page.goto(`${this.baseURL}/s/RefArch/25720033M.html?lang=${locale}`);
    if (itemCount > 1) {
      await this.selectQuantity.selectOption({ index: itemCount });
    }
    await this.addToCartButton.click();
  };

  setShopperDetails = async (shopperDetails) => {
    await this.customerInfoSection.waitFor({ visible: true, timeout: 20000 });


    await this.checkoutPageUserFirstNameInput.type(
      shopperDetails.shopperName.firstName,
    );
    await this.checkoutPageUserLastNameInput.type(
      shopperDetails.shopperName.lastName,
    );
    await this.checkoutPageUserStreetInput.type(shopperDetails.address.street);
    await this.checkoutPageUserHouseNumberInput.type(
      shopperDetails.address.houseNumberOrName,
    );
    await this.checkoutPageUserCityInput.type(shopperDetails.address.city);
    await this.checkoutPageUserPostCodeInput.type(
      shopperDetails.address.postalCode,
    );

    await this.checkoutPageUserCountrySelect.selectOption(
      shopperDetails.address.country,
    );

    await this.checkoutPageUserTelephoneInput.type(shopperDetails.telephone);


    if (await this.checkoutPageUserStateSelect.isVisible()) {
      await this.checkoutPageUserStateSelect.selectOption({ index: 1 })
      if (shopperDetails.address.stateOrProvince !== '') {
        await this.checkoutPageUserStateSelect.selectOption(
          shopperDetails.address.stateOrProvince,
        );
      }
    }

    this.shippingSubmit.scrollIntoViewIfNeeded({ timeout: 5000 });
    await this.submitShipping();
  };

  setEmail = async () => {
    /* After filling the shopper details, clicking "Next" has an autoscroll
    feature, which leads the email field to be missed, hence the flakiness.
    Waiting until the full page load prevents this situation */
    await this.page.waitForLoadState('networkidle');
    await this.checkoutPageUserEmailInput.fill('');
    await this.checkoutPageUserEmailInput.fill('test@adyenTest.com');
  };

  submitShipping = async () => {
    await this.page.waitForLoadState('networkidle', { timeout: 20000 });
    await this.shippingSubmit.click();
    await this.page.waitForNavigation({ waitUntil: "networkidle", timeout: 20000 });

    // Ugly wait since the submit button takes time to mount.
    await new Promise(r => setTimeout(r, 2000));
  };

  submitPayment = async () => {
    await this.page.waitForLoadState('load', { timeout: 30000 });
    await this.submitPaymentButton.click();
  };

  placeOrder = async () => {
    let retries = 3;
    while (retries > 0) {
      try {
        await this.page.waitForLoadState('load', { timeout: 30000 });
        await this.placeOrderButton.click();
        break; // Break out of the loop if successful
      } catch (error) {
        retries--;
        await this.page.reload();
      }
    }
  };

  completeCheckout = async () => {
    await this.submitPayment();
    await this.placeOrder();
  };

  expectSuccess = async () => {
    await this.page.waitForNavigation({
      url: /Order-Confirm/,
      timeout: 20000,
    });
    await expect(this.thankYouMessage).toBeVisible({ timeout: 20000 });
  };
}
