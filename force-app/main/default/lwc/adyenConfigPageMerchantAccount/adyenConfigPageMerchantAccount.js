import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getMerchantAccountConfiguration from '@salesforce/apex/AdyenMerchantAccountController.getMerchantAccountConfiguration';
import fetchMerchantAccounts from '@salesforce/apex/AdyenManagementAPIService.fetchMerchantAccounts';
import updateMerchantAccount from '@salesforce/apex/AdyenMerchantAccountController.updateMerchantAccount';

const METADATA_UPDATE_TIMEOUT = 10000;
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
    
    channelName = '/event/Adyen_Metadata_Deployment_Result__e';
    subscription = null;
    timeoutId = null;
    
    connectedCallback() {
        this.loadMerchantAccount();
        this.subscribeToDeploymentEvents();
    }
    
    disconnectedCallback() {
        this.unsubscribeFromDeploymentEvents();
        this.clearTimeout();
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
                this.apiError = result.errorMessage;
                this.handleAPIError(result.errorMessage);
            }
        } catch (error) {
            this.apiError = 'Error fetching merchant accounts: ' + error.message;
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
        if (eventData.Deployment_Id__c === this.pendingDeploymentId) {
            this.clearTimeout();
            this.isLoading = false;
            this.pendingDeploymentId = '';
            
            if (eventData.Is_Success__c) {
                this.handleDeploymentSuccess();
            } else {
                this.handleDeploymentError(eventData.Error_Message__c);
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
                    'The metadata update is still processing. You can continue with other setup steps.',
                    'warning'
                );
            }
        }, METADATA_UPDATE_TIMEOUT);
    }
    
    clearTimeout() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
            this.timeoutId = null;
        }
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
    }
    
    handleDeploymentError(errorMessage) {
        this.showToast(
            'Error',
            'Failed to update merchant account: ' + (errorMessage || 'Unknown error'),
            'error'
        );
    }
    
    handleRetry() {
        this.fetchMerchantAccountsFromAPI();
    }
    
    handleCancel() {
        this.merchantAccountFetched = false;
        this.selectedMerchantAccountId = '';
        this.apiError = '';
    }
    
    handleFetch() {
        this.fetchMerchantAccountsFromAPI();
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
    
    get selectedMerchantAccount() {
        if (this.selectedMerchantAccountId && this.fetchedMerchantAccounts.length > 0) {
            return this.fetchedMerchantAccounts.find(
                account => account.id === this.selectedMerchantAccountId
            );
        }
        return null;
    }
    
    get showMerchantAccountSection() {
        return !this.isLoading && !this.merchantAccountFetched && !this.apiError;
    }
}