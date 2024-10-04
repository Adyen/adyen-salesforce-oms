import { LightningElement, wire } from 'lwc';
import getExpirationDays from '@salesforce/apex/NonPaymentWebhookHandler.getExpiryDuration';

export default class ChoosePayment extends LightningElement {
    pblSelected = true;
    expirationDays;
    shopperEmail = "danilo.cardoso@adyen.com";

    get pblButtonVariant() {
        return this.pblSelected ? "brand" : "neutral";
    }

    get cardButtonVariant() {
        return this.pblSelected ? "neutral" : "brand";
    }

    get isLoading() {
        if (this.pblSelected) {
            return this.expirationDays == null;
        } else {
            return false;
        }
    }

    @wire(getExpirationDays)
    wiredExpirationDays({ error, data }) {
        if (data) {
            this.expirationDays = data;
        } else if (error) {
            console.error('Error fetching expiration days', error);
        }
    }

    handlePblButtonClick () {
        this.pblSelected = true;
    }

    handleCardButtonClick () {
        this.pblSelected = false;
    }
}