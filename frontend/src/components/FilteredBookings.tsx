import { useState, useEffect } from 'react';
import axios from 'axios';

interface FilteredBookingsProps {
  sessionId: string;
}

export default function FilteredBookings({ sessionId }: FilteredBookingsProps) {
  const [data, setData] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
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
    fetchData();
  }, [sessionId]);

  if (loading) return <div className="text-center mt-8"><span className="spinner"></span></div>;

  return (
    <div className="glass-panel">
      <div className="mb-6">
        <h2>Raw Data & Filtering</h2>
        <p>Below is the original imported data. Bookings filtered out are indicated in the <code>Filtered Out</code> and <code>Filter Reason</code> columns.</p>
        <div className="alert alert-error">
          There are <strong>{total}</strong> bookings filtered out.
        </div>
      </div>

      {data.length > 0 ? (
        <div className="table-container" style={{ maxHeight: '600px', overflowY: 'auto' }}>
          <table>
            <thead>
              <tr>
                {Object.keys(data[0]).map(col => <th key={col}>{col}</th>)}
              </tr>
            </thead>
            <tbody>
              {data.map((row: any, i: number) => (
                <tr key={i} style={{ backgroundColor: row['Filtered Out'] ? 'rgba(239, 68, 68, 0.1)' : 'transparent' }}>
                  {Object.keys(row).map(col => (
                    <td key={col}>{row[col] !== null ? String(row[col]) : ''}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p>No filtered bookings found.</p>
      )}
    </div>
  );
}
