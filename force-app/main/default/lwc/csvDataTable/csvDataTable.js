import { LightningElement, api, wire, track } from 'lwc';
import getCSVData from '@salesforce/apex/CSVDataController.getCSVData';

const PAGE_SIZE = 5;

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

    currentPage = 1;
    totalPages = 1;
    disablePrev = true;
    disableNext = true;

    modalCurrentPage = 1;
    modalTotalPages = 1;
    disablePrevModal = true;
    disableNextModal = true;

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
        if (error) {
            console.error('Error fetching CSV data:', error);
            this.data = [];
            this.paginatedData = [];
            this.summaryData = [];
            return;
        }

        if (data) {
            this.data = data.csvData || [];

            // ✅ Build columns (exclude Id so it doesn’t show as a column)
            if (this.data.length > 0) {
                const fields = Object.keys(this.data[0]).filter(f => f !== 'Id' && f !== 'id');
                this.columns = fields.map(field => ({
                    label: field.replace(/_/g, ' '),
                    fieldName: field,
                    type: 'text'
                }));
            } else {
                this.columns = [];
            }

            this.summaryData = [
                { category: 'Total Apex Class Violations', count: data.clsViolationCount || 0, filterType: 'apex' },
                { category: 'Total LWC Violations', count: data.lwcViolationCount || 0, filterType: 'lwc' },
                { category: 'Total Aura Violations', count: data.auraViolationCount || 0, filterType: 'aura' },
                { category: 'Total Objects Violations', count: data.objectsViolationCount || 0, filterType: 'objects' }
            ];

            this.setPagination();
        }
    }

    // Main pagination
    setPagination() {
        this.totalPages = Math.ceil((this.data.length || 0) / PAGE_SIZE) || 0;
        this.currentPage = 1;
        this.updatePaginatedData();
    }

    updatePaginatedData() {
        if (!this.data || this.data.length === 0) {
            this.paginatedData = [];
            this.disablePrev = true;
            this.disableNext = true;
            return;
        }

        const start = (this.currentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.paginatedData = this.data.slice(start, end);

        this.disablePrev = this.currentPage <= 1;
        this.disableNext = this.currentPage >= this.totalPages;
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

    // Row action -> Modal filter
    handleRowAction(event) {
        const row = event.detail.row;

        const needle =
            row.filterType === 'apex' ? 'classes' :
            row.filterType === 'lwc' ? 'lwc' :
            row.filterType === 'aura' ? 'aura' :
            row.filterType === 'objects' ? 'objects' :
            '';

        this.modalTitle =
            row.filterType === 'apex' ? 'Apex Class Violations' :
            row.filterType === 'lwc' ? 'LWC Violations' :
            row.filterType === 'aura' ? 'Aura Violations' :
            row.filterType === 'objects' ? 'Objects Violations' :
            'Violations';

        this.filteredData = (this.data || []).filter(item => {
            const f = (item.file || '').toLowerCase();
            return needle ? f.includes(needle) : true;
        });

        this.setModalPagination();
        this.isModalOpen = true;
    }

    // Modal pagination
    setModalPagination() {
        this.modalTotalPages = Math.ceil((this.filteredData.length || 0) / PAGE_SIZE) || 0;
        this.modalCurrentPage = 1;
        this.updatePaginatedFilteredData();
    }

    updatePaginatedFilteredData() {
        if (!this.filteredData || this.filteredData.length === 0) {
            this.paginatedFilteredData = [];
            this.disablePrevModal = true;
            this.disableNextModal = true;
            return;
        }

        const start = (this.modalCurrentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.paginatedFilteredData = this.filteredData.slice(start, end);

        this.disablePrevModal = this.modalCurrentPage <= 1;
        this.disableNextModal = this.modalCurrentPage >= this.modalTotalPages;
    }

    handleNextPageModal() {
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

    closeModal() {
        this.isModalOpen = false;
        this.filteredData = [];
        this.paginatedFilteredData = [];
    }
}
