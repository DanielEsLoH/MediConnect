import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useDebounce, useDebounceWithFlush } from "./useDebounce";

describe("useDebounce", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns initial value immediately", () => {
    const { result } = renderHook(() => useDebounce("initial", 300));
    expect(result.current).toBe("initial");
  });

  it("debounces value updates", () => {
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value, 300),
      { initialProps: { value: "initial" } }
    );

    // Update the value
    rerender({ value: "updated" });

    // Should still be initial immediately after update
    expect(result.current).toBe("initial");

    // Advance time partially
    act(() => {
      vi.advanceTimersByTime(200);
    });

    // Still should be initial
    expect(result.current).toBe("initial");

    // Advance past debounce time
    act(() => {
      vi.advanceTimersByTime(150);
    });

    // Now should be updated
    expect(result.current).toBe("updated");
  });

  it("resets timer on rapid updates", () => {
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value, 300),
      { initialProps: { value: "1" } }
    );

    // Rapid updates
    rerender({ value: "2" });
    act(() => vi.advanceTimersByTime(100));

    rerender({ value: "3" });
    act(() => vi.advanceTimersByTime(100));

    rerender({ value: "4" });
    act(() => vi.advanceTimersByTime(100));

    // Should still be "1" because timer keeps resetting
    expect(result.current).toBe("1");

    // Advance past debounce time after last update
    act(() => vi.advanceTimersByTime(300));

    // Now should be "4"
    expect(result.current).toBe("4");
  });

  it("handles type changes correctly", () => {
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value, 300),
      { initialProps: { value: 123 as number } }
    );

    expect(result.current).toBe(123);

    rerender({ value: 456 });
    act(() => vi.advanceTimersByTime(300));

    expect(result.current).toBe(456);
  });

  it("uses default delay of 300ms", () => {
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value),
      { initialProps: { value: "initial" } }
    );

    rerender({ value: "updated" });

    act(() => vi.advanceTimersByTime(250));
    expect(result.current).toBe("initial");

    act(() => vi.advanceTimersByTime(100));
    expect(result.current).toBe("updated");
  });
});

describe("useDebounceWithFlush", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns debounced value and flush function", () => {
    const { result } = renderHook(() => useDebounceWithFlush("initial", 300));
    const [value, flush] = result.current;

    expect(value).toBe("initial");
    expect(typeof flush).toBe("function");
  });

  it("flush immediately updates the value", () => {
    const { result, rerender } = renderHook(
      ({ value }) => useDebounceWithFlush(value, 300),
      { initialProps: { value: "initial" } }
    );

    rerender({ value: "updated" });

    // Value should still be initial
    expect(result.current[0]).toBe("initial");

    // Flush should update immediately
    act(() => {
      result.current[1]();
    });

    expect(result.current[0]).toBe("updated");
  });
});