import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const PAYMENT_MODES = {
    PBL: 'pbl',
    CARD: 'card',
};

const showToast = (title, message, variant) => {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
};

export { PAYMENT_MODES, showToast }