import { useState, useEffect } from 'react';
import axios from 'axios';
import { Save, ChevronDown, ChevronRight, ChevronUp } from 'lucide-react';

import CollapsibleTable from './CollapsibleTable';

interface GroupingPairsProps {
  sessionId: string;
  edits: any[];
  setEdits: React.Dispatch<React.SetStateAction<any[]>>;
  onUpdate: () => void;
}

export default function GroupingPairs({ sessionId, edits, setEdits, onUpdate }: GroupingPairsProps) {
  const [groupings, setGroupings] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

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

  const handleCellChange = (rawId: number, column: string, value: any) => {
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
          
          <CollapsibleTable title="Schools" data={group.schools} columns={group.schools.length > 0 ? Object.keys(group.schools[0]) : []} edits={edits} handleCellChange={handleCellChange} defaultIncluded={true} />
          <CollapsibleTable title="Departments" data={group.departments} columns={group.departments.length > 0 ? Object.keys(group.departments[0]) : []} edits={edits} handleCellChange={handleCellChange} defaultIncluded={true} />
          <CollapsibleTable title="Rooms" data={group.rooms} columns={group.rooms.length > 0 ? Object.keys(group.rooms[0]) : []} edits={edits} handleCellChange={handleCellChange} defaultIncluded={true} />
          <div className="divider"></div>
        </div>
      ))}
    </div>
  );
}
