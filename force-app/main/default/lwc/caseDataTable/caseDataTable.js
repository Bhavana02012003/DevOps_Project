import { LightningElement, api, wire, track } from 'lwc';
import getCSVData from '@salesforce/apex/CaseDataController.getCSVData';

export default class CsvDataTable extends LightningElement {
    @api recordId;
    @track data = [];
    @track columns = [];
    @track summaryData = [];
    @track summaryColumns = [
        { label: 'Category', fieldName: 'category', type: 'text' },
        { label: 'Count', fieldName: 'count', type: 'button', 
            typeAttributes: { 
                label: { fieldName: 'count' }, 
                variant: 'brand', 
                name: 'view_details'
            }  }
    ];
    @track paginatedData = [];
    @track isModalOpen = false;
    @track modalTitle = '';
    @track modalData = [];

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
            // Process main CSV Data
            if (data.csvData && data.csvData.length > 0) {
                this.data = data.csvData.map((row, index) => ({ ...row, Id: index + 1 }));
                this.setPagination();

                if (this.data.length > 0) {
                    this.columns = Object.keys(this.data[0]).map(field => ({
                        label: field.replace(/_/g, ' '),
                        fieldName: field,
                        type: 'text'
                    }));
                }
            }

            // Process Violation Summary Data
            this.summaryData = [
                { category: 'Apex Class Violations', count: data.clsViolationCount || 0, type: 'classes' },
                { category: 'LWC Violations', count: data.lwcViolationCount || 0, type: 'lwc' },
                { category: 'Aura Violations', count: data.auraViolationCount || 0, type: 'aura' },
                { category: 'Objects Violations', count: data.objectsViolationCount || 0, type: 'objects' }
            ];

            console.log('✅ Summary Data:', JSON.stringify(this.summaryData));
        } else {
            this.data = [];
            this.summaryData = [];
        }
    }

    setPagination() {
        this.totalPages = Math.ceil(this.data.length / 5) || 1;
        this.currentPage = 1;
        this.updatePaginatedData();
    }

    updatePaginatedData() {
        const start = (this.currentPage - 1) * 5;
        this.paginatedData = this.data.slice(start, start + 5);
        this.disablePrev = this.currentPage === 1;
        this.disableNext = this.currentPage >= this.totalPages;
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedData();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedData();
        }
    }

    // Open modal and filter data based on category
    openSummaryModal(event) {
        const categoryType = event.detail.row.type;
        this.modalTitle = event.detail.row.category;

        // Filter data based on category type
        this.modalData = this.data.filter(row => {
            return row.File && row.File.includes(categoryType);
        });

        console.log(`✅ Filtered Modal Data for ${categoryType}:`, JSON.stringify(this.modalData));

        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }
}
