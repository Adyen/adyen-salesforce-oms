import { LightningElement, api } from 'lwc';
import updatePaymentLinkStatus from '@salesforce/apex/AdyenPBLController.updatePaymentLinkStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AdyenPBLStatusUpdater extends LightningElement {
    paymentLinkId;

    @api set recordId(value) {
        this.paymentLinkId = value;
        this.updateStatus();
    }

    get recordId() {
        return this.paymentLinkId;
    }

    async updateStatus() {
        try {
            await updatePaymentLinkStatus({ paymentLinkId: this.paymentLinkId });
            this.showToast('Success', 'Payment link status updated successfully.', 'success');
            this.closeComponent();
            window.location.reload();
        } catch (error) {
            const errorMessage = error.body?.message || 'An unknown error occurred.';
            this.showToast('Error', `Failed to update payment link status. ${errorMessage}`, 'error');
            this.closeComponent();
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }

    closeComponent() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
