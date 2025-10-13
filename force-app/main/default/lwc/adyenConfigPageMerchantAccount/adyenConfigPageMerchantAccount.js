import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getMerchantAccountConfiguration from '@salesforce/apex/AdyenMerchantAccountController.getMerchantAccountConfiguration';
import fetchMerchantAccounts from '@salesforce/apex/AdyenManagementAPIService.fetchMerchantAccounts';
import getCompanyId from '@salesforce/apex/AdyenManagementAPIService.getCompanyId';
import updateMerchantAccount from '@salesforce/apex/AdyenMerchantAccountController.updateMerchantAccount';
import getPackageNamespace from '@salesforce/apex/AdyenCustomMetadataService.getPackageNamespace';


const METADATA_UPDATE_TIMEOUT = 30000;
const ERROR_MESSAGES = {
    noMerchantAccounts: 'No merchant accounts found. Please verify your API key has access to merchant accounts.',
    multipleMerchantAccounts: 'Multiple merchant accounts found. Please ensure your API key has 1:1 mapping to your merchant account.',
};


export default class AdyenConfigPageMerchantAccount extends LightningElement {
    currentMerchantAccount = '';
    fetchedMerchantAccounts = [];
    selectedMerchantAccountId = '';
    isLoading = false;
    pendingDeploymentId = '';
    deploymentTimedOut = false;
    apiError = '';
    merchantAccountFetched = false;
    
    showChoiceScreen = true;
    selectedSetupType = 'merchant';
    companyName = '';
    showCompanyConfirmation = false;
    
    channelName;
    subscription = null;
    timeoutId = null;
    namespace = '';
    
    async connectedCallback() {
        this.loadMerchantAccount();
        await this.initializeEventChannel();
    }
    
    disconnectedCallback() {
        this.unsubscribeFromDeploymentEvents();
        this.clearTimeout();
    }
    
    async initializeEventChannel() {
        try {
            this.namespace = await getPackageNamespace();
            const eventName = 'Adyen_Metadata_Deployment_Result__e';
            this.channelName = this.namespace ? `/event/${this.namespace}__${eventName}` : `/event/${eventName}`;
            this.subscribeToDeploymentEvents();
        } catch (error) {
            this.handleError(error, 'Error initializing event channel');
        }
    }

    async loadMerchantAccount() {
        this.isLoading = true;
        try {
            this.currentMerchantAccount = await getMerchantAccountConfiguration();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }
    
    async fetchMerchantAccountsFromAPI() {
        this.isLoading = true;
        this.apiError = '';
        
        this.deploymentTimedOut = false;
        this.pendingDeploymentId = '';
        this.clearTimeout();
        
        try {
            const result = await fetchMerchantAccounts();
            if (result.isSuccess) {
                this.fetchedMerchantAccounts = result.merchantAccounts || [];

                if (this.fetchedMerchantAccounts.length === 0) {
                    this.apiError = ERROR_MESSAGES.noMerchantAccounts;
                    this.showToast('Error', this.apiError, 'error');
                } else if (this.fetchedMerchantAccounts.length === 1) {
                    this.selectedMerchantAccountId = this.fetchedMerchantAccounts[0].id;
                    this.merchantAccountFetched = true;
                } else {
                    this.apiError = ERROR_MESSAGES.multipleMerchantAccounts;
                    this.showToast('Error', this.apiError, 'error');
                }
            } else {
                this.apiError = this.enhanceErrorMessage(result.errorMessage);
                this.handleAPIError(result.errorMessage);
            }
        } catch (error) {
            this.apiError = this.enhanceErrorMessage('Error fetching merchant accounts: ' + error.message);
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }
    
    handleAPIError(errorMessage) {
        const message = errorMessage || 'Failed to fetch merchant account';
        this.showToast('Error', message, 'error');
    }
    
    subscribeToDeploymentEvents() {
        subscribe(this.channelName, -1, (event) => this.handleDeploymentEvent(event))
            .then(response => {
                this.subscription = response;
            })
            .catch(error => {
                this.handleError(error);
            });
    }
    
    unsubscribeFromDeploymentEvents() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }
    
    handleDeploymentEvent(event) {
        const eventData = event.data.payload;
        const nsPrefix = this.namespace ? `${this.namespace}__` : '';

        const deploymentIdField = `${nsPrefix}Deployment_Id__c`;
        const isSuccessField = `${nsPrefix}Is_Success__c`;
        const errorMessageField = `${nsPrefix}Error_Message__c`;

        if (eventData[deploymentIdField] === this.pendingDeploymentId) {
            this.clearTimeout();
            this.isLoading = false;
            this.pendingDeploymentId = '';
            
            if (eventData[isSuccessField]) {
                this.handleDeploymentSuccess();
            } else {
                this.handleDeploymentError(eventData[errorMessageField]);
            }
        }
    }
    
    startTimeout() {
        this.clearTimeout();
        this.deploymentTimedOut = false;
        this.timeoutId = setTimeout(() => {
            if (this.pendingDeploymentId) {
                this.isLoading = false;
                this.deploymentTimedOut = true;
                
                this.showToast(
                    'Deployment Taking Longer Than Expected',
                    'The metadata update is still processing. You can manually update the metadata by following the instructions.',
                    'warning'
                );
                this.scrollToManualUpdateInstructions();
            }
        }, METADATA_UPDATE_TIMEOUT);
    }
    
    clearTimeout() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
            this.timeoutId = null;
        }
    }

    scrollToManualUpdateInstructions() {
        // Wait for the DOM to re-render
        Promise.resolve().then(() => {
            const container = this.template.querySelector('[data-id="instructions-container"]');
            const target = this.template.querySelector('[data-id="manual-update-section"]');
            if (container && target) {
                container.scrollTop = target.offsetTop;
            }
        });
    }
    
    async handleConfirmMerchantAccount() {
        this.isLoading = true;
        this.deploymentTimedOut = false;
        
        try {
            const deploymentId = await updateMerchantAccount({ 
                merchantAccountId: this.selectedMerchantAccountId 
            });
            
            this.pendingDeploymentId = deploymentId;
            this.startTimeout();
            
            this.showToast(
                'Merchant Account Update In Progress',
                'Updating merchant account configuration. This may take a moment.',
                'info'
            );
            
        } catch (error) {
            this.isLoading = false;
            this.handleError(error);
        }
    }
    
    handleDeploymentSuccess() {
        const selectedAccount = this.fetchedMerchantAccounts.find(
            account => account.id === this.selectedMerchantAccountId
        );
        
        if (selectedAccount) {
            this.currentMerchantAccount = selectedAccount.id;
        }
        
        this.merchantAccountFetched = false;
        this.apiError = '';
        
        this.showToast(
            'Success',
            'Merchant account configuration updated successfully.',
            'success'
        );
        
        this.dispatchEvent(new CustomEvent('stepcomplete', {
            detail: {
                step: 'accountSetup',
                success: true,
                setupType: 'merchant',
                merchantAccountId: this.selectedMerchantAccountId
            }
        }));
    }
    
    handleDeploymentError(errorMessage) {
        this.showToast(
            'Error',
            'Failed to update merchant account: ' + (errorMessage || 'Unknown error'),
            'error'
        );
    }
    
    handleSkipAndContinue() {
        this.deploymentTimedOut = false;
        this.pendingDeploymentId = '';
        this.clearTimeout();
        this.isLoading = false;
        
        this.dispatchEvent(new CustomEvent('stepcomplete', {
            detail: {
                step: 'accountSetup',
                success: true,
                setupType: 'merchant',
                merchantAccountId: this.selectedMerchantAccountId
            }
        }));
    }
    
    handleRetry() {
        this.fetchMerchantAccountsFromAPI();
    }
    
    handleCancel() {
        this.merchantAccountFetched = false;
        this.selectedMerchantAccountId = '';
        this.apiError = '';
        
        this.deploymentTimedOut = false;
        this.pendingDeploymentId = '';
        this.clearTimeout();
    }
    
    handleFetch() {
        this.fetchMerchantAccountsFromAPI();
    }
    
    handleSetupTypeChange(event) {
        this.selectedSetupType = event.target.value;
    }
    
    async handleContinueWithChoice() {
        if (!this.selectedSetupType) {
            this.showToast('Error', 'Please select a setup type to continue.', 'error');
            return;
        }
        
        if (this.selectedSetupType === 'company') {
            await this.fetchCompanyDetails();
        } else {
            this.showChoiceScreen = false;
        }
    }
    
    async fetchCompanyDetails() {
        this.isLoading = true;
        try {
            this.companyName = await getCompanyId();
            this.showChoiceScreen = false;
            this.showCompanyConfirmation = true;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }
    
    handleContinueToWebhook() {
        if(this.selectedSetupType === 'merchant') {
            this.selectedMerchantAccountId = this.currentMerchantAccount;
            this.dispatchEvent(new CustomEvent('stepcomplete', {
                detail: {
                    step: 'accountSetup',
                    success: true,
                    setupType: 'merchant',
                    merchantAccountId: this.selectedMerchantAccountId
                }
            }));

        } else {
            this.dispatchEvent(new CustomEvent('stepcomplete', {
                detail: {
                    step: 'accountSetup',
                    success: true,
                    setupType: 'company',
                    companyName: this.companyName
                }
            }));
        }
    }
    
    handleBackToChoice() {
        this.showCompanyConfirmation = false;
        this.companyName = '';
        
        this.merchantAccountFetched = false;
        this.selectedMerchantAccountId = '';
        this.apiError = '';
        
        this.deploymentTimedOut = false;
        this.pendingDeploymentId = '';
        this.clearTimeout();
        
        this.showChoiceScreen = true;
        this.selectedSetupType = 'merchant';
    }
    
    handleError(error, title = 'Error') {
        const errorMessage = error.body ? error.body.message : error.message;
        const enhancedMessage = this.enhanceErrorMessage(errorMessage);
        this.showToast(title, enhancedMessage, 'error');
    }
    
    enhanceErrorMessage(message) {
        if (message?.toLowerCase()?.includes('unauthorized') || message?.toLowerCase()?.includes('forbidden')) {
            return `${message}. Please check your Management API key and ensure it has the correct permissions.`;
        }
        return message;
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
    
    get selectedMerchantAccount() {
        if (this.selectedMerchantAccountId && this.fetchedMerchantAccounts.length > 0) {
            return this.fetchedMerchantAccounts.find(
                account => account.id === this.selectedMerchantAccountId
            );
        }
        return null;
    }
    
    get showMerchantAccountSection() {
        return !this.isLoading && !this.merchantAccountFetched && !this.apiError && !this.showChoiceScreen && !this.showCompanyConfirmation;
    }
    
    get setupTypeOptions() {
        return [
            { label: 'Merchant Account', value: 'merchant' },
            { label: 'Company Account', value: 'company' }
        ];
    }
    
    get isContinueDisabled() {
        return !this.selectedSetupType || this.isLoading;
    }
    
    get showMerchantFlow() {
        return !this.showChoiceScreen && !this.showCompanyConfirmation && this.selectedSetupType === 'merchant';
    }
    
    get headerDescription() {
        if (this.showChoiceScreen) {
            return 'Choose your account configuration type';
        } else if (this.showCompanyConfirmation) {
            return 'Configure webhooks at the company level';
        } else if (this.showMerchantFlow) {
            return 'Configure the merchant account for Adyen integration';
        }
        return 'Choose your account configuration type';
    }
    
    get showChoiceInstructions() {
        return this.showChoiceScreen;
    }
    
    get showMerchantInstructions() {
        return this.selectedSetupType === 'merchant' && !this.showChoiceScreen;
    }
    
    get showCompanyInstructions() {
        return this.showCompanyConfirmation;
    }
}