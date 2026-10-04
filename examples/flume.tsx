import { useState } from "react";

type CounterProps = { step?: number };

/** History makes undo a state transition, not a second counter. */
export function UndoCounter({ step = 1 }: CounterProps) {
    const [history, setHistory] = useState<number[]>([0]);
    const value = history[history.length - 1];
    const canUndo = history.length > 1;

    function increment() {
        // Derive from pending state so queued clicks compose correctly.
        setHistory(previous => [
            ...previous,
            previous[previous.length - 1] + step,
        ]);
    }

    function undo() {
        setHistory(previous =>
            previous.length > 1 ? previous.slice(0, -1) : previous
        );
    }

    return (
        <section aria-label="Undoable counter">
            <output aria-live="polite">Count: {value}</output>
            <button type="button" onClick={increment}>
                Add {step}
            </button>
            <button type="button" onClick={undo} disabled={!canUndo}>
                Undo
            </button>
            <p>{canUndo ? "Every click has a way back." : "At the beginning."}</p>
        </section>
    );
}

export const demo = <UndoCounter step={2} />;
