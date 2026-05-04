import { useState, useEffect } from 'react';
import axios from 'axios';
import { Download } from 'lucide-react';

interface OneSheetProps {
  sessionId: string;
}

export default function OneSheet({ sessionId }: OneSheetProps) {
  const [data, setData] = useState<any[] | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await axios.get(`/api/session/${sessionId}/onesheet`);
        setData(response.data.data);
      } catch (err) {
        console.error("Failed to fetch one sheet data", err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [sessionId]);

  const handleDownload = () => {
    window.location.href = `/api/download/${sessionId}/onesheet_csv`;
  };

  if (loading) return <div className="text-center mt-8"><span className="spinner"></span></div>;

  return (
    <div className="glass-panel">
      <div className="flex justify-between items-center mb-6">
        <h2>One Sheet Update</h2>
        {data && (
          <button onClick={handleDownload} className="btn btn-outline">
            <Download size={18} /> Download CSV
          </button>
        )}
      </div>

      {!data ? (
        <div className="alert">
          Please upload a Historic One Sheet CSV in the uploader on the previous screen to automatically append this year's metrics to it.
        </div>
      ) : (
        <div className="table-container">
          <table>
            <tbody>
              {data.map((row: string[], i: number) => {
                const isHeader = row[1]?.includes('Term') || row[1]?.includes('AY');
                return (
                  <tr key={i} style={{ 
                    backgroundColor: isHeader ? 'rgba(142, 68, 173, 0.2)' : 'transparent',
                    fontWeight: isHeader ? 'bold' : 'normal'
                  }}>
                    {row.map((cell: string, j: number) => (
                      <td key={j}>{cell}</td>
                    ))}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
