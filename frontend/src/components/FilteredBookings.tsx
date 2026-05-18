import { useState, useEffect } from 'react';
import axios from 'axios';
import { Save, X } from 'lucide-react';
import CollapsibleTable from './CollapsibleTable';

interface FilteredBookingsProps {
  sessionId: string;
  edits: any[];
  setEdits: React.Dispatch<React.SetStateAction<any[]>>;
}

export default function FilteredBookings({ sessionId, edits, setEdits }: FilteredBookingsProps) {
  const [data, setData] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const fetchData = async () => {
    try {
      const response = await axios.get(`/api/session/${sessionId}/filtered`);
      setData(response.data.data);
      setTotal(response.data.total_filtered);
    } catch (err) {
      console.error("Failed to fetch filtered data", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [sessionId]);

  const handleCellChange = (rawId: number, column: string, value: any) => {
    setEdits((prev: any[]) => {
      const existing = prev.findIndex(e => e.raw_id === rawId && e.column === column);
      if (existing >= 0) {
        const newEdits = [...prev];
        newEdits[existing].value = value;
        return newEdits;
      }
      return [...prev, { raw_id: rawId, column, value }];
    });
  };

  const handleSave = async () => {
    if (edits.length === 0) return;
    setSaving(true);
    try {
      await axios.post(`/api/session/${sessionId}/groupings`, { edits });
      setEdits([]);
      await fetchData();
    } catch (err) {
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="text-center mt-8"><span className="spinner"></span></div>;

  const misformattedData = data.filter(row => row['Filter Reason'] && String(row['Filter Reason']).includes('Room 000'));

  const columns = data.length > 0 ? Object.keys(data[0]) : [];

  return (
    <div className="glass-panel">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2>Raw Data & Filtering</h2>
          <p className="mb-2">Below is the original imported data. Bookings filtered out are indicated in the <code>Filtered Out</code> and <code>Filter Reason</code> columns.</p>
          <div className="alert alert-error inline-block mb-0">
            There are <strong>{total}</strong> bookings filtered out.
          </div>
        </div>
        <div className="flex gap-4">
          {edits.length > 0 && (
            <button 
              onClick={() => setEdits([])} 
              className="btn"
              style={{ borderColor: 'var(--accent-red)', color: 'var(--accent-red)', background: 'transparent' }}
              disabled={saving}
            >
              <X size={18} /> Discard Changes
            </button>
          )}
          <button 
            onClick={handleSave} 
            className="btn btn-primary"
            disabled={edits.length === 0 || saving}
          >
            {saving ? <span className="spinner"></span> : <><Save size={18} /> Save Changes</>}
          </button>
        </div>
      </div>

      {data.length > 0 ? (
        <div style={{ maxHeight: '600px', overflowY: 'auto' }}>
          {misformattedData.length > 0 && (
            <CollapsibleTable 
              title="Misformatted Rooms" 
              data={misformattedData} 
              columns={columns} 
              edits={edits} 
              handleCellChange={handleCellChange} 
              defaultIncluded={false} 
            />
          )}
          {data.length > 0 && (
            <CollapsibleTable 
              title="Filtered Bookings" 
              data={data} 
              columns={columns} 
              edits={edits} 
              handleCellChange={handleCellChange} 
              defaultIncluded={false} 
            />
          )}
        </div>
      ) : (
        <p>No filtered bookings found.</p>
      )}
    </div>
  );
}
