import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getOrderSummaryIdByOrderNumber from '@salesforce/apex/AdyenOOBOController.getOrderSummaryIdByOrderNumber';
export default class AdyenPblConfirmationScreen extends NavigationMixin(LightningElement) {
    PAYMENT_MODES = {
        PBL: 'pbl',
        CARD: 'card',
    };

    @api shopperName;
    @api paymentLink;
    @api orderReference;
    @api linkExpiryDate;
    @api shopperEmail;
    @api paymentMode;
    @api amount;
    @api currencyIsoCode;

    connectedCallback() {
        this.linkExpiryDate = this.formatDate(this.linkExpiryDate);
    }

    copyPaymentLink() {
        this.copyToClipboard(this.paymentLink);
    }

    copyShopperEmail() {
        this.copyToClipboard(this.shopperEmail);
    }

    get isPblPaymentMode() {
        return this.paymentMode === this.PAYMENT_MODES.PBL;
    }

    get isCardPaymentMode() {
        return this.paymentMode === this.PAYMENT_MODES.CARD;
    }

    async openOrderSummary() {
        try {
            const orderSummaryId = await getOrderSummaryIdByOrderNumber({ orderNumber: this.orderReference });
            const url = await this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: orderSummaryId,
                    objectApiName: 'OrderSummary',
                    actionName: 'view',
                },
            });
            window.open(url, '_blank');
        } catch (error) {
            this.showToast('Error', 'Failed to open order summary', 'error');
        }
    }

    async copyToClipboard(textToCopy) {
        try {
            await navigator.clipboard.writeText(textToCopy);
            this.showToast('Success', 'Copied to clipboard!', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to copy!', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatDate(isoDateStr) {
        const date = new Date(isoDateStr);

        function getOrdinalSuffix(day) {
            if (day > 3 && day < 21) return 'th';
            switch (day % 10) {
                case 1: return 'st';
                case 2: return 'nd';
                case 3: return 'rd';
                default: return 'th';
            }
        }

        const timeOptions = {
            hour: 'numeric',
            minute: 'numeric',
            hour12: true
        };

        const dateOptions = {
            month: 'long',
            year: 'numeric',
            day: 'numeric',
        };

        const formattedTime = new Intl.DateTimeFormat('en-US', timeOptions).format(date);
        let formattedDate = new Intl.DateTimeFormat('en-US', dateOptions).format(date);

        const day = date.getDate();
        const ordinalDay = day + getOrdinalSuffix(day);

        formattedDate = formattedDate.replace(day, ordinalDay);
        return `${formattedTime}, ${formattedDate}`;
    }
}