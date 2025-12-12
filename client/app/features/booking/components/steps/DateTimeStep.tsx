import { useState, useMemo, useCallback } from "react";
import { useBookingStore } from "../../store/bookingStore";
import { Button } from "~/components/ui";
import { cn } from "~/lib/utils";
import type { TimeSlot } from "~/features/appointments";

export interface DateTimeStepProps {
  /** Doctor ID for fetching availability */
  doctorId: number;
  /** Callback when step is completed */
  onNext: () => void;
}

/**
 * Generate time slots for a given date.
 * Creates 30-minute slots from 09:00 to 17:00.
 */
function generateTimeSlots(selectedDate: string): TimeSlot[] {
  const slots: TimeSlot[] = [];
  const startHour = 9; // 09:00
  const endHour = 17; // 17:00

  for (let hour = startHour; hour < endHour; hour++) {
    // First half hour slot
    slots.push({
      start_time: `${hour.toString().padStart(2, "0")}:00`,
      end_time: `${hour.toString().padStart(2, "0")}:30`,
      available: true,
    });

    // Second half hour slot
    slots.push({
      start_time: `${hour.toString().padStart(2, "0")}:30`,
      end_time: `${(hour + 1).toString().padStart(2, "0")}:00`,
      available: true,
    });
  }

  return slots;
}

/**
 * Get today's date in YYYY-MM-DD format.
 */
function getTodayDate(): string {
  return new Date().toISOString().split("T")[0];
}

/**
 * Format a date string for display.
 */
function formatDateForDisplay(dateString: string): string {
  const date = new Date(dateString + "T00:00:00");
  return date.toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

/**
 * Date & Time Selection Step (Step 1)
 *
 * Allows user to:
 * - Select appointment date (within next 30 days)
 * - Choose available time slot (30-min intervals)
 * - View formatted date display
 *
 * State is managed via Zustand store.
 */
export function DateTimeStep({ doctorId, onNext }: DateTimeStepProps) {
  const { selectedDate, startTime, endTime, setDateTime } = useBookingStore();

  // Local state for UI
  const [localDate, setLocalDate] = useState(selectedDate || getTodayDate());
  const [localSlot, setLocalSlot] = useState<TimeSlot | null>(
    startTime && endTime
      ? { start_time: startTime, end_time: endTime, available: true }
      : null
  );

  // Generate time slots for selected date
  const timeSlots = useMemo(() => generateTimeSlots(localDate), [localDate]);

  // Calculate min/max dates
  const minDate = getTodayDate();
  const maxDate = useMemo(() => {
    const date = new Date();
    date.setDate(date.getDate() + 30);
    return date.toISOString().split("T")[0];
  }, []);

  // Handle date change
  const handleDateChange = useCallback((date: string) => {
    setLocalDate(date);
    setLocalSlot(null); // Reset slot when date changes
  }, []);

  // Handle slot selection
  const handleSlotSelect = useCallback((slot: TimeSlot) => {
    setLocalSlot(slot);
  }, []);

  // Handle next button click
  const handleNext = useCallback(() => {
    if (!localSlot) return;

    // Save to store
    setDateTime(localDate, localSlot.start_time, localSlot.end_time);

    // Proceed to next step
    onNext();
  }, [localDate, localSlot, setDateTime, onNext]);

  const canProceed = !!localSlot;

  return (
    <div className="space-y-6">
      {/* Date Selector */}
      <div>
        <label
          htmlFor="appointment-date"
          className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
        >
          Select Date
        </label>
        <input
          type="date"
          id="appointment-date"
          value={localDate}
          min={minDate}
          max={maxDate}
          onChange={(e) => handleDateChange(e.target.value)}
          className={cn(
            "w-full rounded-lg border bg-white transition-colors duration-200",
            "px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm",
            "min-h-[44px] sm:min-h-[40px]",
            "text-gray-900 dark:text-gray-100",
            "border-gray-300 dark:border-gray-700",
            "hover:border-gray-400 dark:hover:border-gray-600",
            "focus:outline-none focus:ring-2 focus:ring-primary-500/20 focus:border-primary-500",
            "dark:bg-gray-900"
          )}
          aria-describedby="date-helper"
        />
        <p
          id="date-helper"
          className="mt-1.5 text-sm text-gray-500 dark:text-gray-400"
        >
          {formatDateForDisplay(localDate)}
        </p>
      </div>

      {/* Time Slots */}
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Available Time Slots
        </label>
        <div
          className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-2"
          role="group"
          aria-label="Available time slots"
        >
          {timeSlots.map((slot) => {
            const isSelected =
              localSlot?.start_time === slot.start_time &&
              localSlot?.end_time === slot.end_time;

            return (
              <button
                key={slot.start_time}
                type="button"
                disabled={!slot.available}
                onClick={() => handleSlotSelect(slot)}
                className={cn(
                  "py-2 px-2 text-sm font-medium rounded-lg transition-all duration-200",
                  "min-h-[44px] sm:min-h-[40px]",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
                  slot.available
                    ? isSelected
                      ? "bg-primary-600 text-white shadow-md scale-105"
                      : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-primary-100 dark:hover:bg-primary-900 hover:text-primary-700 dark:hover:text-primary-300"
                    : "bg-gray-50 dark:bg-gray-900 text-gray-400 dark:text-gray-600 cursor-not-allowed"
                )}
                aria-pressed={isSelected}
                aria-label={`${slot.start_time} to ${slot.end_time}${!slot.available ? ", unavailable" : ""}`}
              >
                {slot.start_time}
              </button>
            );
          })}
        </div>
      </div>

      {/* Selected Time Summary */}
      {localSlot && (
        <div className="p-4 bg-primary-50 dark:bg-primary-950 rounded-lg">
          <h3 className="text-sm font-medium text-primary-900 dark:text-primary-100 mb-2">
            Selected Slot
          </h3>
          <div className="space-y-1 text-sm text-primary-700 dark:text-primary-300">
            <p>
              <span className="font-medium">Date:</span>{" "}
              {formatDateForDisplay(localDate)}
            </p>
            <p>
              <span className="font-medium">Time:</span> {localSlot.start_time} -{" "}
              {localSlot.end_time}
            </p>
          </div>
        </div>
      )}

      {/* Next Button */}
      <div className="flex justify-end pt-4 border-t border-gray-200 dark:border-gray-800">
        <Button
          variant="primary"
          onClick={handleNext}
          disabled={!canProceed}
          className="min-w-[120px]"
        >
          Next
        </Button>
      </div>

      {!localSlot && (
        <p className="text-center text-sm text-gray-500 dark:text-gray-400">
          Please select a time slot to continue
        </p>
      )}
    </div>
  );
}
