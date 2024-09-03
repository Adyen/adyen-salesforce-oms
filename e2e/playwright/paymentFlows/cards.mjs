import PaymentMethodsPage from '../pages/PaymentMethodsPage.mjs';
export class Cards {
  constructor(page) {
    this.page = page;
    this.paymentMethodsPage = new PaymentMethodsPage(page);
  }

  doCardPayment = async (cardData) => {
    await this.paymentMethodsPage.initiateCardPayment(cardData);
  };
}
