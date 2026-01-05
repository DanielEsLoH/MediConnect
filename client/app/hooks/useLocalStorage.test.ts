import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useLocalStorage } from "./useLocalStorage";

describe("useLocalStorage", () => {
  beforeEach(() => {
    // Clear localStorage before each test
    localStorage.clear();
    vi.clearAllMocks();
  });

  afterEach(() => {
    localStorage.clear();
  });

  it("returns initial value when localStorage is empty", () => {
    const { result } = renderHook(() => useLocalStorage("test-key", "default"));
    expect(result.current[0]).toBe("default");
  });

  it("returns stored value from localStorage", () => {
    localStorage.setItem("test-key", JSON.stringify("stored-value"));

    const { result } = renderHook(() => useLocalStorage("test-key", "default"));
    expect(result.current[0]).toBe("stored-value");
  });

  it("updates localStorage when value changes", () => {
    const { result } = renderHook(() => useLocalStorage("test-key", "initial"));

    act(() => {
      result.current[1]("updated");
    });

    expect(result.current[0]).toBe("updated");
    expect(JSON.parse(localStorage.getItem("test-key") || "")).toBe("updated");
  });

  it("supports function updates", () => {
    const { result } = renderHook(() => useLocalStorage("test-key", 0));

    act(() => {
      result.current[1]((prev) => prev + 1);
    });

    expect(result.current[0]).toBe(1);

    act(() => {
      result.current[1]((prev) => prev + 1);
    });

    expect(result.current[0]).toBe(2);
  });

  it("handles object values", () => {
    const initialObject = { name: "John", age: 30 };
    const { result } = renderHook(() => useLocalStorage("test-key", initialObject));

    expect(result.current[0]).toEqual(initialObject);

    act(() => {
      result.current[1]({ name: "Jane", age: 25 });
    });

    expect(result.current[0]).toEqual({ name: "Jane", age: 25 });
    expect(JSON.parse(localStorage.getItem("test-key") || "")).toEqual({
      name: "Jane",
      age: 25,
    });
  });

  it("handles array values", () => {
    const { result } = renderHook(() => useLocalStorage("test-key", [1, 2, 3]));

    expect(result.current[0]).toEqual([1, 2, 3]);

    act(() => {
      result.current[1]((prev) => [...prev, 4]);
    });

    expect(result.current[0]).toEqual([1, 2, 3, 4]);
  });

  it("handles invalid JSON in localStorage gracefully", () => {
    localStorage.setItem("test-key", "not valid json");

    const { result } = renderHook(() => useLocalStorage("test-key", "default"));
    expect(result.current[0]).toBe("default");
  });

  it("uses different keys independently", () => {
    const { result: result1 } = renderHook(() =>
      useLocalStorage("key1", "value1")
    );
    const { result: result2 } = renderHook(() =>
      useLocalStorage("key2", "value2")
    );

    expect(result1.current[0]).toBe("value1");
    expect(result2.current[0]).toBe("value2");

    act(() => {
      result1.current[1]("updated1");
    });

    expect(result1.current[0]).toBe("updated1");
    expect(result2.current[0]).toBe("value2");
  });

  it("persists values across re-renders", () => {
    const { result, rerender } = renderHook(() =>
      useLocalStorage("test-key", "initial")
    );

    act(() => {
      result.current[1]("updated");
    });

    rerender();

    expect(result.current[0]).toBe("updated");
  });
});