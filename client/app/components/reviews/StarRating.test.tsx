import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { StarRating } from "./StarRating";

describe("StarRating", () => {
  describe("display mode (readOnly)", () => {
    it("renders correct number of stars", () => {
      render(<StarRating rating={3} readOnly />);
      const stars = screen.getAllByRole("img", { hidden: true });
      expect(stars).toHaveLength(5);
    });

    it("displays correct rating with filled stars", () => {
      render(<StarRating rating={4} readOnly />);
      // Should have 4 filled stars and 1 empty
      expect(screen.getByLabelText(/4 out of 5 stars/i)).toBeInTheDocument();
    });

    it("shows numeric value when showValue is true", () => {
      render(<StarRating rating={4.5} readOnly showValue />);
      expect(screen.getByText("4.5")).toBeInTheDocument();
    });

    it("handles different sizes", () => {
      const { container, rerender } = render(<StarRating rating={3} size="sm" readOnly />);
      expect(container.querySelector(".w-4")).toBeInTheDocument();

      rerender(<StarRating rating={3} size="lg" readOnly />);
      expect(container.querySelector(".w-6")).toBeInTheDocument();
    });
  });

  describe("input mode", () => {
    it("is interactive when not readOnly", async () => {
      const onChange = vi.fn();
      render(<StarRating rating={0} onChange={onChange} />);

      const stars = screen.getAllByRole("button");
      expect(stars).toHaveLength(5);
    });

    it("calls onChange when star is clicked", async () => {
      const onChange = vi.fn();
      render(<StarRating rating={0} onChange={onChange} />);

      const stars = screen.getAllByRole("button");
      await userEvent.click(stars[2]); // Click 3rd star

      expect(onChange).toHaveBeenCalledWith(3);
    });

    it("updates visual state on hover", async () => {
      render(<StarRating rating={0} onChange={vi.fn()} />);

      const stars = screen.getAllByRole("button");
      await userEvent.hover(stars[3]); // Hover 4th star

      // The star should show hover preview
      expect(stars[3]).toHaveAttribute("aria-label");
    });

    it("supports keyboard navigation", async () => {
      const onChange = vi.fn();
      render(<StarRating rating={3} onChange={onChange} />);

      const stars = screen.getAllByRole("button");
      stars[2].focus();

      // Arrow right should increase rating
      await userEvent.keyboard("{ArrowRight}");
      expect(onChange).toHaveBeenCalledWith(4);

      // Arrow left should decrease rating
      await userEvent.keyboard("{ArrowLeft}");
      expect(onChange).toHaveBeenCalledWith(2);
    });
  });

  describe("accessibility", () => {
    it("has proper aria labels for display mode", () => {
      render(<StarRating rating={4.5} readOnly />);
      expect(screen.getByLabelText(/4.5 out of 5 stars/i)).toBeInTheDocument();
    });

    it("has proper aria labels for input mode", () => {
      render(<StarRating rating={0} onChange={vi.fn()} label="Rate this doctor" />);
      expect(screen.getByLabelText(/rate this doctor/i)).toBeInTheDocument();
    });

    it("stars are focusable in input mode", () => {
      render(<StarRating rating={0} onChange={vi.fn()} />);
      const stars = screen.getAllByRole("button");
      stars.forEach((star) => {
        expect(star).not.toHaveAttribute("tabindex", "-1");
      });
    });
  });

  describe("custom maxRating", () => {
    it("renders correct number of stars with custom max", () => {
      render(<StarRating rating={3} maxRating={10} readOnly />);
      const stars = screen.getAllByRole("img", { hidden: true });
      expect(stars).toHaveLength(10);
    });
  });
});