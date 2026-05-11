import { useState, useEffect } from 'react';
import axios from 'axios';
import { Save } from 'lucide-react';

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
        <button 
          onClick={handleSave} 
          className="btn btn-primary"
          disabled={edits.length === 0 || saving}
        >
          {saving ? <span className="spinner"></span> : <><Save size={18} /> Save Changes</>}
        </button>
      </div>

      {data.length > 0 ? (
        <div className="table-container" style={{ maxHeight: '600px', overflowY: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th style={{ width: '80px' }}>Include</th>
                {Object.keys(data[0]).map(col => <th key={col}>{col}</th>)}
              </tr>
            </thead>
            <tbody>
              {data.map((row: any, i: number) => {
                const filterEdit = edits.find((e: any) => e.raw_id === row._raw_id && e.column === 'Manual Override Filtered');
                // By default in FilteredBookings, row is NOT included (Filtered Out = True)
                const isIncluded = filterEdit ? !filterEdit.value : false;

                return (
                <tr key={row._raw_id || i} style={{ backgroundColor: row['Filtered Out'] ? 'rgba(239, 68, 68, 0.1)' : 'transparent' }}>
                  <td className="text-center">
                    <input 
                      type="checkbox" 
                      checked={isIncluded} 
                      onChange={(e) => handleCellChange(row._raw_id, 'Manual Override Filtered', !e.target.checked)} 
                      style={{ cursor: 'pointer', transform: 'scale(1.2)' }}
                    />
                  </td>
                  {Object.keys(row).map(col => (
                    <td key={col}>{row[col] !== null ? String(row[col]) : ''}</td>
                  ))}
                </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : (
        <p>No filtered bookings found.</p>
      )}
    </div>
  );
}
