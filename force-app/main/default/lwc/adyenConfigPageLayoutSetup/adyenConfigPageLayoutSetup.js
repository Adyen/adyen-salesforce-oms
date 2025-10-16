import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupPageUrls from '@salesforce/apex/AdyenConfigPageController.getSetupPageUrls';

const BUTTON_CONFIG = {
    salesChannelLayout: {
        urlKey: 'salesChannelLayouts',
    },
    paymentLayout: {
        urlKey: 'paymentLayouts',
    },
    paymentAuthorizationLayout: {
        urlKey: 'paymentAuthorizationLayouts',
    }
};

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
    
    handleNavigateToSetup(event) {
        const action = event.currentTarget.dataset.action;
        const config = BUTTON_CONFIG[action];

        if (config && this.setupUrls[config.urlKey]) {
            window.open(this.setupUrls[config.urlKey], '_blank');
        } else {
            this.showToast('Error', 'Unable to open the page layouts setup page.', 'error');
        }
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

    handleButtonMouseOver(event) {
        this.currentInstructionSet = event.currentTarget.dataset.action;
    }
}