pragma Singleton

import QtQuick

// byte quantities are 1024-based everywhere in the shell, so the labels are
// IEC (KiB/MiB/GiB) to match the math
QtObject {

    // scales b into the 1024 ladder, returns { v, div, unit }
    function scaleBytes(b: real): var {
        const units = ["B", "KiB", "MiB", "GiB"];
        let div = 1;
        let i = 0;
        while (b / div >= 1024 && i < units.length - 1) {
            div *= 1024;
            i++;
        }
        return {
            v: b / div,
            div: div,
            unit: units[i]
        };
    }

    function bytes(b: real): string {
        const s = scaleBytes(b);
        // decimals grow with the unit: B whole, KiB one, MiB and up two
        const dec = s.unit === "B" ? 0 : s.unit === "KiB" ? 1 : 2;
        return s.v.toFixed(dec) + " " + s.unit;
    }

    function rate(bps: real): string {
        if (bps < 0)
            return "";
        return bytes(bps) + "/s";
    }

    // "used / total Unit" with the unit picked from total; coarser precision
    // than bytes() because these render inside narrow usage rows
    function pair(used: real, total: real): string {
        const s = scaleBytes(total);
        const dec = s.unit === "GiB" ? 1 : 0;
        return (used / s.div).toFixed(dec) + " / " + s.v.toFixed(dec) + " " + s.unit;
    }
}
