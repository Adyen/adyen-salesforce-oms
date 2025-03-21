import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { PAYMENT_MODES } from 'c/payByLinkUtils';
import getOrderSummaryIdByOrderNumber from '@salesforce/apex/AdyenOOBOController.getOrderSummaryIdByOrderNumber';

export default class AdyenPblConfirmationScreen extends NavigationMixin(LightningElement) {
    @api shopperName;
    @api paymentLink;
    @api orderReference;
    @api linkExpiryDate;
    @api shopperEmail;
    @api paymentMode;
    @api amount;
    @api currencyIsoCode;

    connectedCallback() {
        if (this.isPblPaymentMode) {
            this.linkExpiryDate = this.formatDate(this.linkExpiryDate);
        }
    }

    copyPaymentLink() {
        this.copyToClipboard(this.paymentLink);
    }

    copyShopperEmail() {
        this.copyToClipboard(this.shopperEmail);
    }

    get isPblPaymentMode() {
        return this.paymentMode === PAYMENT_MODES.PBL;
    }

    get isCardPaymentMode() {
        return this.paymentMode === PAYMENT_MODES.CARD;
    }

    async openOrderSummary() {
        try {
            const orderSummaryId = await getOrderSummaryIdByOrderNumber({ orderNumber: this.orderReference });
            const recordUrl = `/lightning/r/${orderSummaryId}/view`;
            window.open(recordUrl, '_blank');
        } catch (error) {
            this.showToast('Error', 'Failed to open order summary', 'error');
        }
    }

    copyToClipboard(textToCopy) {
        const textArea = document.createElement('textarea');
        textArea.value = textToCopy;
        document.body.appendChild(textArea);
        textArea.select();
        try {
            document.execCommand('copy');
            this.showToast('Success', 'Copied to clipboard!', 'success');
        } catch (err) {
            this.showToast('Error', 'Failed to copy!', 'error');
        }
        document.body.removeChild(textArea);
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
        const timezone = new Intl.DateTimeFormat('en-US', { timeZoneName: 'short' }).format(date).split(' ').pop();

        return `${formattedTime}, ${formattedDate} (${timezone})`;
    }
}
