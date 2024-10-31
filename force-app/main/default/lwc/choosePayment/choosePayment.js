import { LightningElement, api } from 'lwc';
import getExpirationDays from '@salesforce/apex/AdyenOOBOController.getExpiryDuration';
import getAccountNameAndEmail from '@salesforce/apex/AdyenOOBOController.getAccountEmailAndName';
import { PAYMENT_MODES } from 'c/payByLinkUtils';

export default class ChoosePayment extends LightningElement {
    pblSelected = true;
    expirationDays;
    error;
    isLoading;
    @api accountId;
    @api shopperEmail;
    @api shopperName;
    @api paymentMode;

    async connectedCallback() {
        this.isLoading = true;
        this.handlePblButtonClick(); // initializing values
        try {
            await Promise.all([
                this.fetchExpirationDays(),
                this.fetchShopperInfo(),
            ]);
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    async fetchExpirationDays() {
        this.expirationDays = await getExpirationDays();
    }

    async fetchShopperInfo() {
        const shopperInfo = await getAccountNameAndEmail({ accountId: this.accountId });
        this.shopperName = shopperInfo.name;
        this.shopperEmail = shopperInfo.email;
    }

    handlePblButtonClick() {
        this.pblSelected = true;
        this.paymentMode = PAYMENT_MODES.PBL;
    }
}
