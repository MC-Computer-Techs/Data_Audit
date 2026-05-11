import { useState, useEffect } from 'react';
import axios from 'axios';
import { Download } from 'lucide-react';

interface TopSheetProps {
  sessionId: string;
}

export default function TopSheet({ sessionId }: TopSheetProps) {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await axios.get(`/api/session/${sessionId}/summary`);
        setData(response.data);
      } catch (err) {
        console.error("Failed to fetch summary data", err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [sessionId]);

  const handleDownload = (type: 'pdf' | 'excel') => {
    window.location.href = `/api/download/${sessionId}/${type}`;
  };

  if (loading) return <div className="text-center mt-8"><span className="spinner"></span></div>;
  if (!data) return <div className="alert alert-error">Failed to load data.</div>;

  return (
    <div className="glass-panel">
      <div className="flex justify-between items-center mb-6">
        <h2>Top Sheet Overview</h2>
        <div className="flex gap-4">
          <button onClick={() => handleDownload('pdf')} className="btn btn-outline">
            <Download size={18} /> Download PDF
          </button>
          <button onClick={() => handleDownload('excel')} className="btn btn-outline">
            <Download size={18} /> Download Excel
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-8">
        <div className="metric-card">
          <div className="metric-label">Total Reservations</div>
          <div className="metric-value">{data.total_reservations}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Total Hours</div>
          <div className="metric-value">{data.total_hours}</div>
        </div>
      </div>

      <div className="table-container">
        <table>
          <tbody>
            {data.top_sheet_data.map((row: string[], i: number) => {
              const isHeaderRow = i === 2 || row[row.length - 1]?.includes("Total:");
              const isSectionTitle = row[0] && !row[1] && !row[2] && row[0] !== "Reservation Data Audit" && !row[0].includes("If some");

              return (
                <tr key={i} style={{ 
                  backgroundColor: isHeaderRow ? 'rgba(59, 130, 246, 0.2)' : isSectionTitle ? 'rgba(255, 255, 255, 0.05)' : 'transparent',
                  fontWeight: (isHeaderRow || isSectionTitle) ? 'bold' : 'normal'
                }}>
                  {row.map((cell: string, j: number) => (
                    <td key={j} style={{ 
                      textAlign: j === 0 ? 'left' : 'center',
                      paddingLeft: (j === 0 && !isHeaderRow && !isSectionTitle) ? '1.5rem' : '1rem'
                    }}>
                      {cell}
                    </td>
                  ))}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
