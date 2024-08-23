export default class PaymentMethodsPage {
  constructor(page) {
    this.page = page;
  }

  initiateCardPayment = async (cardInput) => {
    await this.page.locator('#rb_scheme').click();

    const ccComponentWrapper = this.page.locator("#component_scheme");

    await ccComponentWrapper
      .locator('.adyen-checkout__card__holderName__input')
      .fill(cardInput.holderName);

    const cardNumberInputField = ccComponentWrapper
      .frameLocator('.adyen-checkout__card__cardNumber__input iframe')
      .locator('.input-field');
    await cardNumberInputField.click();
    await cardNumberInputField.fill(cardInput.cardNumber);

    const expirationDateInputField = ccComponentWrapper
      .frameLocator('.adyen-checkout__card__exp-date__input iframe')
      .locator('.input-field');
    await expirationDateInputField.click();
    await expirationDateInputField.fill(cardInput.expirationDate);

    if (cardInput.cvc !== '') {
      const cvcInputField = ccComponentWrapper
        .frameLocator('.adyen-checkout__card__cvc__input iframe')
        .locator('.input-field');
      await cvcInputField.click();
      await cvcInputField.fill(cardInput.cvc);
    }
  };
}
