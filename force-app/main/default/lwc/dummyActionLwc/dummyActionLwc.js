import { LightningElement } from 'lwc';

export default class DummyActionLwc extends LightningElement {
    connectedCallback() {
        // Deliberate Violation: strict "no-console" rule
        console.log('Testing LWC Delta Scanner'); 
    }
}