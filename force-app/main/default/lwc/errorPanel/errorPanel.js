import { LightningElement, api } from 'lwc';
import { reduceErrors } from 'c/ldsUtils';
import noDataIllustration from './templates/noDataIllustration.html';
import inlineMessage from './templates/inlineMessage.html';

export default class ErrorPanel extends LightningElement {
    viewDetails = false;

    /** Single or array of LDS errors */
    @api errors;
    /** Generic / user-friendly message */
    @api friendlyMessage = 'An error has occurred.';
    /** Type of error message **/
    @api type;

    get errorMessages() {
        return reduceErrors(this.errors);
    }

    handleShowDetailsClick() {
        this.viewDetails = !this.viewDetails;
    }

    render() {
        if (this.type === 'inlineMessage') return inlineMessage;
        return noDataIllustration;
    }
}