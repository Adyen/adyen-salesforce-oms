import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AdyenOMSConfigPage extends LightningElement {
    currentStep = 'paymentGateway';
    
    steps = [
        { value: 'paymentGateway', label: 'Payment Gateway' },
        { value: 'namedCredential', label: 'Named Credentials' },
        { value: 'siteURL', label: 'Site URL Setup' },
        { value: 'merchantAccount', label: 'Merchant Account' },
        { value: 'webhookSetup', label: 'Webhook Setup' },
        { value: 'pageLayoutSetup', label: 'Page Layout Setup' }
    ];
    
    handleStepClick(event) {
        this.currentStep = event.currentTarget.dataset.step;
    }
    
    handleStepComplete(event) {        
        const completedStep = event.detail.step || this.currentStep;
        const success = event.detail.success;
        if (success) {
            this.moveToNextStep(completedStep);
        }
    }
    
    handleNextStep() {
        this.moveToNextStep(this.currentStep);
    }
    
    moveToNextStep(currentStep = this.currentStep) {
        const currentIndex = this.steps.findIndex(step => step.value === currentStep);
        
        if (currentIndex === -1) {
            this.showToast('Error', 'Invalid step.', 'error');
            return;
        }
        
        if (currentIndex < this.steps.length - 1) {
            this.currentStep = this.steps[currentIndex + 1].value;
        }
    }

     handlePreviousStep() {
        const currentIndex = this.steps.findIndex(step => step.value === this.currentStep);
        if (currentIndex > 0) {
            this.currentStep = this.steps[currentIndex - 1].value;    
        }
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
    
    get isPaymentGatewayStep() {
        return this.currentStep === 'paymentGateway';
    }
    
    get isNamedCredentialStep() {
        return this.currentStep === 'namedCredential';
    }
    
    get isSiteURLStep() {
        return this.currentStep === 'siteURL';
    }

    get isMerchantAccountStep() {
        return this.currentStep === 'merchantAccount';
    }

    get isWebhookSetupStep() {
        return this.currentStep === 'webhookSetup';
    }

    get isPageLayoutSetupStep() {
        return this.currentStep === 'pageLayoutSetup';
    }
    
    get isFirstStep() {
        const currentIndex = this.steps.findIndex(step => step.value === this.currentStep);
        return currentIndex === 0;
    }

    get isLastStep() {
        const currentIndex = this.steps.findIndex(step => step.value === this.currentStep);
        return currentIndex === this.steps.length - 1;
    }
    
    getStepClass(stepValue) {
        if (this.currentStep === stepValue) {
            return 'slds-path__item slds-is-current slds-is-active';
        }
        
        const stepIndex = this.steps.findIndex(step => step.value === stepValue);
        const currentIndex = this.steps.findIndex(step => step.value === this.currentStep);
        
        if (stepIndex < currentIndex) {
            return 'slds-path__item slds-is-complete';
        }
        
        return 'slds-path__item';
    }
    
    get paymentGatewayStepClass() {
        return this.getStepClass('paymentGateway');
    }
    
    get namedCredentialStepClass() {
        return this.getStepClass('namedCredential');
    }
    
    get siteURLStepClass() {
        return this.getStepClass('siteURL');
    }
    
    get merchantAccountStepClass() {
        return this.getStepClass('merchantAccount');
    }
    
    get webhookSetupStepClass() {
        return this.getStepClass('webhookSetup');
    }

    get pageLayoutSetupStepClass() {
        return this.getStepClass('pageLayoutSetup');
    }

}