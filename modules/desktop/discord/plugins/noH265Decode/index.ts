import { IS_LINUX } from "@utils/constants";
import definePlugin from "@utils/types";

// the native engine reports h265 decode on linux, but the client hardcodes
// software-h265=0 and the linux receive path has no hardware h265 decoder.
// the stream lands on NullVideoDecoder, which never errors, so decoder
// fallback never fires and the viewer gets a black stream.
// see https://github.com/flathub/com.discordapp.Discord/issues/565
// TODO: remove once discord stops advertising h265 decode it can't do
function dropH265Decode(capabilities: string) {
    if (!IS_LINUX) return capabilities;
    const codecs: { codec: string; decode: boolean; encode: boolean; }[] = JSON.parse(capabilities);
    for (const c of codecs) {
        if (c.codec === "H265") c.decode = false;
    }
    return JSON.stringify(codecs);
}

export default definePlugin({
    name: "NoH265Decode",
    description: "Stops advertising H.265 decode on Linux so streams fall back to a codec the client can decode",
    authors: [{ name: "tetra", id: 0n }],
    dropH265Decode,
    patches: [
        {
            find: "Experimental codecs: ",
            replacement: {
                // the go live connection and the clip replay connection each build a codec list
                match: /getCodecCapabilities\((\i)=>\{/g,
                replace: "$&$1=$self.dropH265Decode($1);"
            }
        }
    ]
});
