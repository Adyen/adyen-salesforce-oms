import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupPageUrls from '@salesforce/apex/AdyenConfigPageController.getSetupPageUrls';

export default class AdyenConfigPageLayoutSetup extends LightningElement {
    setupUrls = {};
    showSpinner = false;
    stepName = 'pageLayouts';
    currentInstructionSet = 'default';
    
    get showDefaultInstructions() {
        return this.currentInstructionSet === 'default';
    }
    
    get showSalesChannelLayoutInstructions() {
        return this.currentInstructionSet === 'salesChannelLayout';
    }
    
    get showPaymentLayoutInstructions() {
        return this.currentInstructionSet === 'paymentLayout';
    }
    
    get showPaymentAuthorizationLayoutInstructions() {
        return this.currentInstructionSet === 'paymentAuthorizationLayout';
    }
    
    connectedCallback() {
        this.fetchSetupUrls();
    }
    
    async fetchSetupUrls() {
        this.showSpinner = true;
        try {
            this.setupUrls = await getSetupPageUrls();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.showSpinner = false;
        }
    }
    
    handleSetupSalesChannelLayout() {
        if (this.setupUrls.salesChannelLayouts) {
            window.open(this.setupUrls.salesChannelLayouts, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Sales Channel page layouts setup page.', 'error');
        }
    }
    
    handleSetupPaymentLayout() {
        if (this.setupUrls.paymentLayouts) {
            window.open(this.setupUrls.paymentLayouts, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Payment page layouts setup page.', 'error');
        }
    }
    
    handleSetupPaymentAuthorizationLayout() {
        if (this.setupUrls.paymentAuthorizationLayouts) {
            window.open(this.setupUrls.paymentAuthorizationLayouts, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Payment Authorization page layouts setup page.', 'error');
        }
    }

    handleButtonMouseOver(event) {
        const instructionType = event.currentTarget.dataset.instructiontype;
        this.currentInstructionSet = instructionType;
    }
    
    handleError(error) {
        const errorMessage = error.body ? error.body.message : error.message;
        this.showToast('Error', errorMessage, 'error');
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}