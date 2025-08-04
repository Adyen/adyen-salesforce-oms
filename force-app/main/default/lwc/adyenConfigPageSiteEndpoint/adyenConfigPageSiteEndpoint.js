import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupPageUrls from '@salesforce/apex/AdyenConfigPageController.getSetupPageUrls';
import getSiteEndpointStatus from '@salesforce/apex/AdyenConfigPageController.getSiteEndpointStatus';

export default class AdyenConfigPageSiteEndpoint extends LightningElement {
    @track setupUrls = {};
    showSpinner = false;
    stepName = 'siteUrl';
    currentInstructionSet = 'default';
    isAlreadyConfigured = false;
    acknowledgedExistingConfig = false;
    
    get showDefaultInstructions() {
        return this.currentInstructionSet === 'default';
    }
    
    get showSiteEndpointInstructions() {
        return this.currentInstructionSet === 'siteEndpoint';
    }
    
    get showUpdateUrlInstructions() {
        return this.currentInstructionSet === 'updateUrl';
    }

    get showExistingConfigInfo() {
        return this.isAlreadyConfigured && !this.acknowledgedExistingConfig;
    }
    
    connectedCallback() {
        this.loadInitialData();
    }
    
    async loadInitialData() {
        this.showSpinner = true;
        try {
            const [urls, status] = await Promise.all([
                getSetupPageUrls(),
                getSiteEndpointStatus()
            ]);
            this.setupUrls = urls;
            if (status.hasError) {
                this.handleError(status.errorMessage);
                return;
            }
   
            if (status.isNamedCredentialConfigured && status.siteExists) {
                this.isAlreadyConfigured = true;
            }
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
    
    handleProceed() {
        this.acknowledgedExistingConfig = true;
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