import { useState } from 'react';
import axios from 'axios';
import { FileSpreadsheet, FileText, Settings, Layout, Layers, FileDigit, Filter } from 'lucide-react';
import TopSheet from './components/TopSheet';
import GroupingPairs from './components/GroupingPairs';
import OneSheet from './components/OneSheet';
import FilteredBookings from './components/FilteredBookings';

function App() {
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<string>('top_sheet');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [startDate, setStartDate] = useState('2024-09-01');
  const [endDate, setEndDate] = useState('2025-08-31');
  const [csvFile, setCsvFile] = useState<File | null>(null);
  const [excelFile, setExcelFile] = useState<File | null>(null);
  const [oneSheetFile, setOneSheetFile] = useState<File | null>(null);

  const handleProcessData = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!csvFile && !excelFile) {
      setError("Please upload either a Booking Tool CSV or an existing Excel Audit.");
      return;
    }

    setLoading(true);
    setError(null);
    setSuccess(null);

    const formData = new FormData();
    formData.append('start_date', startDate);
    formData.append('end_date', endDate);
    if (csvFile) formData.append('csv_file', csvFile);
    if (excelFile) formData.append('excel_file', excelFile);
    if (oneSheetFile) formData.append('one_sheet_file', oneSheetFile);

    try {
      const response = await axios.post('/api/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setSessionId(response.data.session_id);
      setSuccess(response.data.message);
    } catch (err: any) {
      setError(err.response?.data?.detail || "An error occurred during processing.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container">
      <header className="mb-8">
        <h1 className="flex items-center gap-4">
          <Settings size={36} className="text-primary" />
          Reservation Data Audit Application
        </h1>
        <p>Upload the Booking Tool reservations CSV file to generate Grouping Pairs, Top Sheet, and One Sheet stats.</p>
      </header>

      {!sessionId && (
        <form onSubmit={handleProcessData} className="glass-panel">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <label>Start Date</label>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                required
              />
            </div>
            <div>
              <label>End Date</label>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4 mb-8">
            <div className="file-upload-wrapper">
              <div className="file-upload-input">
                <FileSpreadsheet size={32} className="mb-2 text-secondary mx-auto" />
                <p>{csvFile ? csvFile.name : "Upload 'Booking Tool' CSV"}</p>
                <input type="file" accept=".csv" onChange={(e) => setCsvFile(e.target.files?.[0] || null)} />
              </div>
            </div>
            <div className="file-upload-wrapper">
              <div className="file-upload-input">
                <FileText size={32} className="mb-2 text-secondary mx-auto" />
                <p>{excelFile ? excelFile.name : "Upload Existing Excel Audit"}</p>
                <input type="file" accept=".xlsx" onChange={(e) => setExcelFile(e.target.files?.[0] || null)} />
              </div>
            </div>
            <div className="file-upload-wrapper">
              <div className="file-upload-input">
                <FileDigit size={32} className="mb-2 text-secondary mx-auto" />
                <p>{oneSheetFile ? oneSheetFile.name : "Upload Historic 'One Sheet' (Optional)"}</p>
                <input type="file" accept=".csv" onChange={(e) => setOneSheetFile(e.target.files?.[0] || null)} />
              </div>
            </div>
          </div>

          {error && <div className="alert alert-error">{error}</div>}

          <button type="submit" className="btn btn-primary w-full" disabled={loading}>
            {loading ? <span className="spinner"></span> : "Process Data"}
          </button>
        </form>
      )}

      {success && <div className="alert alert-success mt-4">{success}</div>}

      {sessionId && (
        <div className="mt-8">
          <div className="tabs-header">
            <button
              className={`tab-btn flex items-center gap-2 ${activeTab === 'top_sheet' ? 'active' : ''}`}
              onClick={() => setActiveTab('top_sheet')}
            >
              <Layout size={18} /> Top Sheet Overview
            </button>
            <button
              className={`tab-btn flex items-center gap-2 ${activeTab === 'grouping_pairs' ? 'active' : ''}`}
              onClick={() => setActiveTab('grouping_pairs')}
            >
              <Layers size={18} /> Grouping Pairs
            </button>
            <button
              className={`tab-btn flex items-center gap-2 ${activeTab === 'one_sheet' ? 'active' : ''}`}
              onClick={() => setActiveTab('one_sheet')}
            >
              <FileDigit size={18} /> One Sheet Update
            </button>
            <button
              className={`tab-btn flex items-center gap-2 ${activeTab === 'filtered' ? 'active' : ''}`}
              onClick={() => setActiveTab('filtered')}
            >
              <Filter size={18} /> Filtered Bookings
            </button>
          </div>

          <div className="tabs-container">
            {activeTab === 'top_sheet' && <TopSheet sessionId={sessionId} />}
            {activeTab === 'grouping_pairs' && <GroupingPairs sessionId={sessionId} onUpdate={() => {
              // Trigger a refresh logic if needed, but the child components handle their own data fetches
            }} />}
            {activeTab === 'one_sheet' && <OneSheet sessionId={sessionId} />}
            {activeTab === 'filtered' && <FilteredBookings sessionId={sessionId} />}
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
