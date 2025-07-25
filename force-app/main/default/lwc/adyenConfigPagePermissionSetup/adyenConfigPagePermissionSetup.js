import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPermissionSetUrls from '@salesforce/apex/AdyenConfigPageController.getPermissionSetUrls';

export default class AdyenConfigPagePermissionSetup extends LightningElement {
    setupUrls = {};
    showSpinner = false;
    stepName = 'permissionSetup';
    currentInstructionSet = 'default';
    
    get showDefaultInstructions() {
        return this.currentInstructionSet === 'default';
    }
    
    get showRecordTypeInstructions() {
        return this.currentInstructionSet === 'recordType';
    }
    
    get showPaymentAuthorizationInstructions() {
        return this.currentInstructionSet === 'paymentAuthorization';
    }
    
    get showPaymentInstructions() {
        return this.currentInstructionSet === 'payment';
    }
    
    connectedCallback() {
        this.fetchSetupUrls();
    }
    
    async fetchSetupUrls() {
        this.showSpinner = true;
        try {
            this.setupUrls = await getPermissionSetUrls();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.showSpinner = false;
        }
    }
    
    handleNavigateToPermissionSet() {
        if (this.setupUrls.omsB2cPermissionSetUrl) {
            window.open(this.setupUrls.omsB2cPermissionSetUrl, '_blank');
        } else {
            this.showToast('Error', 'Unable to open the Permission Set page.', 'error');
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