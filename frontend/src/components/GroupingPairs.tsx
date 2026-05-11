import { useState, useEffect } from 'react';
import axios from 'axios';
import { Save, ChevronDown, ChevronRight, ChevronUp } from 'lucide-react';

interface CollapsibleTableProps {
  title: string;
  data: any[];
  columns: string[];
  edits: any[];
  handleCellChange: (rawId: number, column: string, value: string) => void;
}

const CollapsibleTable = ({ title, data, columns, edits, handleCellChange }: CollapsibleTableProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [sortConfig, setSortConfig] = useState<{ key: string; direction: 'ascending' | 'descending' } | null>(null);
  
  if (!data || data.length === 0) return null;

  const handleSort = (key: string) => {
    let direction: 'ascending' | 'descending' = 'ascending';
    if (sortConfig && sortConfig.key === key && sortConfig.direction === 'ascending') {
      direction = 'descending';
    }
    setSortConfig({ key, direction });
  };

  const sortedData = [...data];
  if (sortConfig !== null) {
    sortedData.sort((a, b) => {
      let aVal = a[sortConfig.key];
      let bVal = b[sortConfig.key];
      
      const aEdit = edits.find(e => e.raw_id === a._raw_id && e.column === sortConfig.key);
      const bEdit = edits.find(e => e.raw_id === b._raw_id && e.column === sortConfig.key);
      if (aEdit) aVal = aEdit.value;
      if (bEdit) bVal = bEdit.value;
      
      if (aVal === null || aVal === undefined) aVal = '';
      if (bVal === null || bVal === undefined) bVal = '';

      if (typeof aVal === 'number' && typeof bVal === 'number') {
        return sortConfig.direction === 'ascending' ? aVal - bVal : bVal - aVal;
      }
      
      const aStr = String(aVal).toLowerCase();
      const bStr = String(bVal).toLowerCase();

      if (!isNaN(Number(aStr)) && !isNaN(Number(bStr)) && aStr.trim() !== '' && bStr.trim() !== '') {
         const aNum = Number(aStr);
         const bNum = Number(bStr);
         return sortConfig.direction === 'ascending' ? aNum - bNum : bNum - aNum;
      }

      if (aStr < bStr) {
        return sortConfig.direction === 'ascending' ? -1 : 1;
      }
      if (aStr > bStr) {
        return sortConfig.direction === 'ascending' ? 1 : -1;
      }
      return 0;
    });
  }

  return (
    <div className="mb-4">
      <div 
        className="flex items-center cursor-pointer p-3 transition"
        style={{ background: 'rgba(15, 23, 42, 0.6)', border: '1px solid var(--glass-border)', borderRadius: 'var(--border-radius)' }}
        onClick={() => setIsOpen(!isOpen)}
      >
        {isOpen ? <ChevronDown size={20} className="mr-2" style={{ color: 'var(--primary-accent)' }} /> : <ChevronRight size={20} className="mr-2" style={{ color: 'var(--primary-accent)' }} />}
        <h4 className="m-0 flex-1" style={{ margin: 0 }}>{title} <span className="text-sm font-normal ml-2" style={{ color: 'var(--text-secondary)' }}>({data.length} records)</span></h4>
      </div>
      
      {isOpen && (
        <div className="mt-3">
          <div className="table-container mb-3">
            <table>
              <thead>
                <tr>
                  {columns.map(col => (
                    <th 
                      key={col} 
                      onClick={() => handleSort(col)}
                      style={{ cursor: 'pointer', userSelect: 'none' }}
                      className="hover:bg-slate-700 transition group"
                    >
                      <div className="flex items-center">
                        {col}
                        <span className={`ml-1 flex items-center transition-opacity ${sortConfig?.key === col ? 'opacity-100' : 'opacity-0 group-hover:opacity-50'}`}>
                          {sortConfig?.key === col ? (
                            sortConfig.direction === 'ascending' ? <ChevronUp size={14} className="text-primary" /> : <ChevronDown size={14} className="text-primary" />
                          ) : (
                            <ChevronDown size={14} />
                          )}
                        </span>
                      </div>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {sortedData.map((row: any, i: number) => (
                  <tr key={row._raw_id || i}>
                    {columns.map(col => {
                      const isEditable = !['Calc Hours', 'ACTUAL hours', 'Time In Use, Hours', '_raw_id', 'Filtered Out', 'Filter Reason', 'All Depts'].includes(col);
                      
                      const edit = edits.find((e: any) => e.raw_id === row._raw_id && e.column === col);
                      const displayValue = edit ? edit.value : row[col];

                      if (isEditable) {
                        return (
                          <td key={col} className="editable-cell">
                            <input 
                              type="text" 
                              value={displayValue || ''} 
                              onChange={(e) => handleCellChange(row._raw_id, col, e.target.value)}
                            />
                          </td>
                        );
                      }
                      return <td key={col}>{row[col] !== null ? String(row[col]) : ''}</td>;
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};

interface GroupingPairsProps {
  sessionId: string;
  onUpdate: () => void;
}

export default function GroupingPairs({ sessionId, onUpdate }: GroupingPairsProps) {
  const [groupings, setGroupings] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [edits, setEdits] = useState<any[]>([]);

  const fetchGroupings = async () => {
    try {
      const response = await axios.get(`/api/session/${sessionId}/groupings`);
      setGroupings(response.data.groupings);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchGroupings();
  }, [sessionId]);

  const handleCellChange = (rawId: number, column: string, value: string) => {
    setEdits(prev => {
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
      await fetchGroupings();
      onUpdate();
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
          <h2>Generated Grouping Pairs</h2>
          <p className="mb-0">Edit values below to update quantities. Click save to recalculate totals.</p>
        </div>
        <button 
          onClick={handleSave} 
          className="btn btn-primary"
          disabled={edits.length === 0 || saving}
        >
          {saving ? <span className="spinner"></span> : <><Save size={18} /> Save Changes</>}
        </button>
      </div>

      {groupings.map((group: any) => (
        <div key={group.semester} className="mb-8">
          <h3 className="mb-4 text-primary">{group.semester_code} ({group.semester})</h3>
          
          <CollapsibleTable title="Schools" data={group.schools} columns={group.schools.length > 0 ? Object.keys(group.schools[0]) : []} edits={edits} handleCellChange={handleCellChange} />
          <CollapsibleTable title="Departments" data={group.departments} columns={group.departments.length > 0 ? Object.keys(group.departments[0]) : []} edits={edits} handleCellChange={handleCellChange} />
          <CollapsibleTable title="Rooms" data={group.rooms} columns={group.rooms.length > 0 ? Object.keys(group.rooms[0]) : []} edits={edits} handleCellChange={handleCellChange} />
          <div className="divider"></div>
        </div>
      ))}
    </div>
  );
}
