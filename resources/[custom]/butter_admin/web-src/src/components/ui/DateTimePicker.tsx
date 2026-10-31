import React, { useState, useEffect, useRef } from 'react';

interface DateTimePickerProps {
  value?: { day: number; month: number; year: number; hour: number; min: number };
  onChange: (value: { day: number; month: number; year: number; hour: number; min: number }) => void;
}

const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

export const DateTimePicker: React.FC<DateTimePickerProps> = ({ value, onChange }) => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const now = new Date();
  const [currentMonth, setCurrentMonth] = useState(value ? value.month - 1 : now.getMonth());
  const [currentYear, setCurrentYear] = useState(value ? value.year : now.getFullYear());

  const [selectedDay, setSelectedDay] = useState(value ? value.day : now.getDate());
  const [selectedHour, setSelectedHour] = useState(value ? value.hour : 23);
  const [selectedMin, setSelectedMin] = useState(value ? value.min : 59);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    if (value) {
      setSelectedDay(value.day);
      setCurrentMonth(value.month - 1);
      setCurrentYear(value.year);
      setSelectedHour(value.hour);
      setSelectedMin(value.min);
    }
  }, [value]);

  const getDaysInMonth = (month: number, year: number) => {
    return new Date(year, month + 1, 0).getDate();
  };

  const getFirstDayOfMonth = (month: number, year: number) => {
    return new Date(year, month, 1).getDay();
  };

  const handlePrevMonth = () => {
    if (currentMonth === 0) {
      setCurrentMonth(11);
      setCurrentYear(currentYear - 1);
    } else {
      setCurrentMonth(currentMonth - 1);
    }
  };

  const handleNextMonth = () => {
    if (currentMonth === 11) {
      setCurrentMonth(0);
      setCurrentYear(currentYear + 1);
    } else {
      setCurrentMonth(currentMonth + 1);
    }
  };

  const handleApply = () => {
    onChange({
      day: selectedDay,
      month: currentMonth + 1,
      year: currentYear,
      hour: selectedHour,
      min: selectedMin,
    });
    setIsOpen(false);
  };

  const daysInMonth = getDaysInMonth(currentMonth, currentYear);
  const firstDay = getFirstDayOfMonth(currentMonth, currentYear);
  const days = Array.from({ length: daysInMonth }, (_, i) => i + 1);
  const emptyDays = Array.from({ length: firstDay }, (_, i) => i);

  const formatTime = (h: number, m: number) => {
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
  };

  const formatDate = () => {
    if (!value) return 'Select expiration date & time';
    return `${value.day.toString().padStart(2, '0')} ${MONTHS[value.month - 1].substring(0, 3)} ${value.year} at ${formatTime(value.hour, value.min)}`;
  };

  return (
    <div className="relative w-full" ref={containerRef}>
      <div
        onClick={() => setIsOpen(!isOpen)}
        className="w-full bg-black/40 border border-white/10 rounded-lg px-4 py-2.5 text-white font-rajdhani cursor-pointer hover:border-accent/50 transition-colors flex justify-between items-center"
      >
        <span>{formatDate()}</span>
        <i className="fa-regular fa-calendar text-white/50"></i>
      </div>

      {isOpen && (
        <div className="absolute top-full left-0 mt-2 w-72 bg-black border border-white/10 rounded-lg z-50 p-4 animate-in fade-in slide-in-from-top-2 duration-200">
          {/* Calendar Header */}
          <div className="flex justify-between items-center mb-4">
            <button
              onClick={handlePrevMonth}
              className="w-8 h-8 rounded hover:bg-white/10 flex items-center justify-center text-white/70 transition-colors"
            >
              <i className="fa-solid fa-chevron-left text-xs"></i>
            </button>
            <div className="font-rajdhani font-semibold text-white tracking-wider">
              {MONTHS[currentMonth]} {currentYear}
            </div>
            <button
              onClick={handleNextMonth}
              className="w-8 h-8 rounded hover:bg-white/10 flex items-center justify-center text-white/70 transition-colors"
            >
              <i className="fa-solid fa-chevron-right text-xs"></i>
            </button>
          </div>

          {/* Days of Week */}
          <div className="grid grid-cols-7 gap-1 mb-2">
            {['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((day) => (
              <div key={day} className="text-center text-xs font-rajdhani text-white/40 uppercase">
                {day}
              </div>
            ))}
          </div>

          {/* Calendar Grid */}
          <div className="grid grid-cols-7 gap-1 mb-4">
            {emptyDays.map((empty) => (
              <div key={`empty-${empty}`} className="h-8"></div>
            ))}
            {days.map((day) => {
              const isSelected = day === selectedDay;
              const isToday =
                day === now.getDate() && currentMonth === now.getMonth() && currentYear === now.getFullYear();

              return (
                <button
                  key={day}
                  onClick={() => setSelectedDay(day)}
                  className={`h-8 rounded-md flex items-center justify-center text-sm font-rajdhani transition-all ${
                    isSelected
                      ? 'bg-accent text-white font-bold'
                      : isToday
                        ? 'bg-white/10 text-accent font-bold hover:bg-white/20'
                        : 'text-white/80 hover:bg-white/10'
                  }`}
                >
                  {day}
                </button>
              );
            })}
          </div>

          <div className="h-px w-full bg-white/10 mb-4"></div>

          {/* Time Picker */}
          <div className="flex items-center justify-between mb-4">
            <span className="text-sm font-rajdhani text-white/60 uppercase tracking-wider">Time</span>
            <div className="flex items-center gap-2">
              <input
                type="number"
                min="0"
                max="23"
                value={selectedHour}
                onChange={(e) => setSelectedHour(Math.min(23, Math.max(0, parseInt(e.target.value) || 0)))}
                className="w-12 bg-black/40 border border-white/10 rounded px-2 py-1 text-center text-white font-mono text-sm focus:outline-none focus:border-accent/50"
              />
              <span className="text-white/50">:</span>
              <input
                type="number"
                min="0"
                max="59"
                value={selectedMin}
                onChange={(e) => setSelectedMin(Math.min(59, Math.max(0, parseInt(e.target.value) || 0)))}
                className="w-12 bg-black/40 border border-white/10 rounded px-2 py-1 text-center text-white font-mono text-sm focus:outline-none focus:border-accent/50"
              />
            </div>
          </div>

          {/* Actions */}
          <button
            onClick={handleApply}
            className="w-full bg-accent hover:bg-accent/90 text-white font-rajdhani uppercase tracking-wider py-2 rounded transition-colors"
          >
            Apply Date & Time
          </button>
        </div>
      )}
    </div>
  );
};
