import { LightningElement, api, wire, track } from 'lwc';
import getCSVData from '@salesforce/apex/CaseDataController.getCSVData';

export default class CsvDataTable extends LightningElement {
    @api recordId;
    @track data = [];
    @track columns = [];
    @track summaryData = [];
    @track paginatedData = [];
    @track isModalOpen = false;
    @track modalTitle = '';

    currentPage = 1;
    totalPages = 1;
    disablePrev = true;
    disableNext = true;

    @wire(getCSVData, { caseId: '$recordId' })
    wiredCSVData({ error, data }) {
        if (error) {
            console.error('❌ Error fetching CSV data:', error);
            this.data = [];
            return;
        }

        console.log('✅ CSV Data Retrieved:', JSON.stringify(data));

        if (data) {
            this.data = data.csvData || [];
            this.setPagination();

            if (this.data.length > 0) {
                this.columns = Object.keys(this.data[0]).map(field => ({
                    label: field.replace(/_/g, ' '),
                    fieldName: field,
                    type: 'text'
                }));
            }

            this.summaryData = [
                { category: 'Apex Class Violations', count: data.clsViolationCount || 0 },
                { category: 'LWC Violations', count: data.lwcViolationCount || 0 },
                { category: 'Aura Violations', count: data.auraViolationCount || 0 },
                { category: 'Objects Violations', count: data.objectsViolationCount || 0 }
            ];
        }
    }

    setPagination() {
        this.totalPages = Math.ceil(this.data.length / 5);
        this.currentPage = 1;
        this.updatePaginatedData();
    }

    updatePaginatedData() {
        const start = (this.currentPage - 1) * 5;
        this.paginatedData = this.data.slice(start, start + 5);
        this.disablePrev = this.currentPage === 1;
        this.disableNext = this.currentPage === this.totalPages;
    }
}
