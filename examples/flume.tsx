declare namespace JSX {
    interface IntrinsicElements {
        section: { children?: unknown };
        span: { children?: unknown };
    }
}

type Props = { value: number };

/** A component is not a typed value constructor. */
function ResultCard({ value }: Props) {
    return <section><span>folded = {value}</span></section>;
}

const view = <ResultCard value={40 + 2} />;
export { view };
