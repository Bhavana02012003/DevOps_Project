import { LightningElement, api, wire, track } from 'lwc';
import getCSVData from '@salesforce/apex/CSVDataController.getCSVData';

const PAGE_SIZE = 5; // Display 5 rows per page

export default class CsvDataTable extends LightningElement {
    @api recordId;
    @track data = [];
    @track columns = [];
    @track summaryData = [];
    @track filteredData = [];
    @track paginatedData = [];
    @track paginatedFilteredData = [];
    @track isModalOpen = false;
    @track modalTitle = '';

    // Pagination variables for main datatable
    currentPage = 1;
    totalPages = 1;
    disablePrev = true;
    disableNext = true;

    // Pagination variables for modal datatable
    modalCurrentPage = 1;
    modalTotalPages = 1;
    disablePrevModal = true;
    disableNextModal = true;

    // Table columns for summary data
    summaryColumns = [
        { label: 'Violation Type', fieldName: 'category', type: 'text' },
        { 
            label: 'Count', 
            fieldName: 'count', 
            type: 'button', 
            typeAttributes: { 
                label: { fieldName: 'count' }, 
                variant: 'brand', 
                name: 'view_details'
            } 
        }
    ];

    @wire(getCSVData, { caseId: '$recordId' })
    wiredCSVData({ error, data }) {
        if (data) {
            this.data = data.csvData;
            this.setPagination();

            // Extract column headers dynamically
            if (this.data.length > 0) {
                this.columns = Object.keys(this.data[0]).map(field => ({
                    label: field.replace(/_/g, ' '),
                    fieldName: field,
                    type: 'text'
                }));
            }

            // Prepare Summary Data
            this.summaryData = [
                { category: 'Total Apex Class Violations', count: data.clsViolationCount, filterType: 'apex' },
                { category: 'Total LWC Violations', count: data.lwcViolationCount, filterType: 'lwc' }
            ];
        } else if (error) {
            this.data = [];
        }
    }

    // Set Pagination for Main Table
    setPagination() {
        this.totalPages = Math.ceil(this.data.length / PAGE_SIZE);
        this.currentPage = 1;
        this.updatePaginatedData();
    }

    updatePaginatedData() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.paginatedData = this.data.slice(start, end);

        this.disablePrev = this.currentPage === 1;
        this.disableNext = this.currentPage === this.totalPages;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedData();
        }
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedData();
        }
    }

    // Handle Click Event on Count Column
    handleRowAction(event) {
        const row = event.detail.row;

        if (row.filterType === 'apex') {
            this.modalTitle = 'Apex Class Violations';
            this.filteredData = this.data.filter(item => item.File && item.File.includes('classes'));
        } else if (row.filterType === 'lwc') {
            this.modalTitle = 'LWC Violations';
            this.filteredData = this.data.filter(item => item.File && item.File.includes('lwc'));
        }

        this.setModalPagination();
        this.isModalOpen = true;
    }

    // Set Pagination for Modal Table
    setModalPagination() {
        this.modalTotalPages = Math.ceil(this.filteredData.length / PAGE_SIZE);
        this.modalCurrentPage = 1;
        this.updatePaginatedFilteredData();
    }

    updatePaginatedFilteredData() {
        const start = (this.modalCurrentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.paginatedFilteredData = this.filteredData.slice(start, end);

        this.disablePrevModal = this.modalCurrentPage === 1;
        this.disableNextModal = this.modalCurrentPage === this.modalTotalPages;
    }

    handleNextModalPage() {
        if (this.modalCurrentPage < this.modalTotalPages) {
            this.modalCurrentPage++;
            this.updatePaginatedFilteredData();
        }
    }

    handlePrevModalPage() {
        if (this.modalCurrentPage > 1) {
            this.modalCurrentPage--;
            this.updatePaginatedFilteredData();
        }
    }

    // Close Modal
    closeModal() {
        this.isModalOpen = false;
        this.filteredData = [];
    }
}
