interface SelectItem {
    label: string;
    detail?: string;
}

/** Filtering resets selection so a hidden item cannot stay active. */
export class Selection<T extends SelectItem> {
    private visible: readonly T[];
    private index = 0;

    constructor(private readonly items: readonly T[]) {
        this.visible = items;
    }

    setFilter(input: string): void {
        const prefix = input.trim().toLowerCase();
        this.visible = this.items.filter(item =>
            item.label.toLowerCase().startsWith(prefix)
        );
        this.index = 0;
    }

    get selected(): T | undefined {
        return this.visible[this.index];
    }

    render(): string[] {
        return this.visible.map(({ label, detail }) =>
            detail ? `${label} — ${detail}` : label
        );
    }
}

const picker = new Selection([
    { label: "Read", detail: "Open a document" },
    { label: "Retry", detail: "Keep the owned input" },
]);
picker.setFilter("re");
console.log(picker.selected?.label ?? "No match", picker.render());
