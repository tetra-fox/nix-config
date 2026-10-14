pragma Singleton

import QtQuick

// byte math is 1024-based everywhere, so labels are IEC
QtObject {

    // returns { v, div, unit }
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
        const dec = s.unit === "B" ? 0 : s.unit === "KiB" ? 1 : 2;
        return s.v.toFixed(dec) + " " + s.unit;
    }

    function rate(bps: real): string {
        if (bps < 0)
            return "";
        return bytes(bps) + "/s";
    }

    // unit picked from total, coarser than bytes() for narrow usage rows
    function pair(used: real, total: real): string {
        const s = scaleBytes(total);
        const dec = s.unit === "GiB" ? 1 : 0;
        return (used / s.div).toFixed(dec) + " / " + s.v.toFixed(dec) + " " + s.unit;
    }
}
