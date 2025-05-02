import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupPageUrls from '@salesforce/apex/AdyenConfigPageController.getSetupPageUrls';

export default class AdyenConfigPageNamedCredential extends LightningElement {
    @track setupUrls = {};
    showSpinner = false;
    stepName = 'namedCredential';
    
    currentInstructionSet = 'default';
    currentCredential = '';
    
    get showDefaultInstructions() {
        return this.currentInstructionSet === 'default';
    }
    
    get showApiKeyInstructions() {
        return this.currentInstructionSet === 'apiKey';
    }
    
    get showPermissionsInstructions() {
        return this.currentInstructionSet === 'permissions';
    }

    get isManagementAPI() {
        return this.currentCredential === 'AdyenManagementAPI';
    }
    
    async connectedCallback() {
        await this.fetchSetupUrls();
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
    
    handleUpdateApiKey(event) {
        const credentialName = event.currentTarget.dataset.credential;
        const credentialUrls = {
            'AdyenCheckout': this.setupUrls.checkoutNamedCredential,
            'AdyenManagementAPI': this.setupUrls.managementApiNamedCredential
        };
    
        const setupUrl = credentialUrls[credentialName];
    
        if (setupUrl) {
            window.open(setupUrl, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Named Credential setup page.', 'error');
        }
    }

    handleAssignPermissions() {
        if (this.setupUrls.permissionSet) {
            window.open(this.setupUrls.permissionSet, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Permission Set setup page.', 'error');
        }
    }
    
    
    handleButtonMouseOver(event) {
        const buttonType = event.currentTarget.dataset.buttontype;
        const credentialName = event.currentTarget.dataset.credential;
        
        this.currentCredential = credentialName;
        this.currentInstructionSet = buttonType;
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