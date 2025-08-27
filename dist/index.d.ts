// dist/index.d.ts
export interface Exiv2Module {
    read(u8: Uint8Array): { exif: Record<string, string>; iptc: Record<string, string>; xmp: Record<string, string> };
    readTagText(u8: Uint8Array, key: string): string | null;
    readTagBytes(u8: Uint8Array, key: string): Uint8Array | null;
    writeString(u8: Uint8Array, key: string, value: string): Uint8Array;
    writeBytes(u8: Uint8Array, key: string, data: Uint8Array): Uint8Array;
  }
  
  export function createExiv2Module(
    options?: Record<string, unknown>
  ): Promise<Exiv2Module>;
  