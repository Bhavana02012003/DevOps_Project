// this comment starts with a lowercase letter to trigger 'capitalized-comments'

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, api } from 'lwc';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

export default class DummyEslintTester extends LightningElement {
    @api recordId;

    // another uncapitalized comment just to be safe
    connectedCallback() {
        /* assigning a dummy variable so we don't trigger no-empty-functions */
        let testVar = true; 
        console.log('Componsdsdsdent Loasdsing Bro pleases check the voilations');
        if (testVar) {
            this.recordId = '001000000000000';
        }
    }
}