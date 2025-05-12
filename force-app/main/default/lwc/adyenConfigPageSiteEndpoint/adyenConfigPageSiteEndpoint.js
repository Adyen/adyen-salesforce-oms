import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupPageUrls from '@salesforce/apex/AdyenConfigPageController.getSetupPageUrls';

export default class AdyenConfigPageSiteEndpoint extends LightningElement {
    @track setupUrls = {};
    showSpinner = false;
    stepName = 'siteUrl';
    currentInstructionSet = 'default';
    
    get showDefaultInstructions() {
        return this.currentInstructionSet === 'default';
    }
    
    get showSiteEndpointInstructions() {
        return this.currentInstructionSet === 'siteEndpoint';
    }
    
    get showUpdateUrlInstructions() {
        return this.currentInstructionSet === 'updateUrl';
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
    
    handleSetupSiteEndpoint() {
        if (this.setupUrls.siteSetup) {
            window.open(this.setupUrls.siteSetup, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Site setup page.', 'error');
        }
    }
    
    handleUpdateSiteUrl() {
        if (this.setupUrls.webhookNamedCredential) {
            window.open(this.setupUrls.webhookNamedCredential, '_blank');
        } else {
            this.showToast('Error', 'Unable to open Named Credential setup page.', 'error');
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