#include <string>
#include <vector>
#include <sstream>
#include "exiv2/exiv2.hpp"
#include <emscripten/bind.h>
#include <emscripten/val.h>

using namespace emscripten;

// JS Uint8Array -> std::vector<byte>
static std::vector<Exiv2::byte> toBytes(val u8) {
    const size_t len = u8["length"].as<size_t>();
    std::vector<Exiv2::byte> data(len);
    val view = val(typed_memory_view(len, data.data()));
    view.call<void>("set", u8);
    return data;
}

// std::vector<uint8_t> -> JS Uint8Array
static val toUint8Array(const std::vector<unsigned char>& v) {
    val out = val::global("Uint8Array").new_(static_cast<unsigned int>(v.size()));
    val view = val(typed_memory_view(v.size(), v.data()));
    out.call<void>("set", view);
    return out;
}

static Exiv2::Image::UniquePtr openFromMemory(const std::vector<Exiv2::byte>& buf) {
    auto memio = std::make_unique<Exiv2::MemIo>(buf.data(), buf.size());
    return Exiv2::ImageFactory::open(std::move(memio));
}

val read(val u8) {
    try {
        auto bytes = toBytes(u8);
        auto image = openFromMemory(bytes);
        if (!image) return val::object();
        Exiv2::XmpParser::initialize();
        image->readMetadata();

        val result = val::object();

        // EXIF
        {
            val ex = val::object();
            Exiv2::ExifData& exif = image->exifData();
            for (const auto& md : exif) ex.set(md.key(), md.toString());
            result.set("exif", ex);
        }
        // IPTC
        {
            val ip = val::object();
            Exiv2::IptcData& iptc = image->iptcData();
            for (const auto& md : iptc) ip.set(md.key(), md.toString());
            result.set("iptc", ip);
        }
        // XMP
        {
            val xm = val::object();
            Exiv2::XmpData& xmp = image->xmpData();
            for (const auto& md : xmp) xm.set(md.key(), md.toString());
            result.set("xmp", xm);
        }
        return result;
    } catch (const std::exception& e) {
        EM_ASM({ console.error('read() exception:', UTF8ToString($0)); }, e.what());
        return val::object();
    }
}

val readTagText(val u8, const std::string& key) {
    try {
        auto bytes = toBytes(u8);
        auto image = openFromMemory(bytes);
        if (!image) return val::null();
        Exiv2::XmpParser::initialize();
        image->readMetadata();

        if (key.rfind("Exif.", 0) == 0) {
            Exiv2::ExifKey k(key);
            auto& ex = image->exifData();
            auto it = ex.findKey(k);
            if (it != ex.end()) return val(it->toString());
        } else if (key.rfind("Iptc.", 0) == 0) {
            Exiv2::IptcKey k(key);
            auto& ip = image->iptcData();
            auto it = ip.findKey(k);
            if (it != ip.end()) return val(it->toString());
        } else if (key.rfind("Xmp.", 0) == 0) {
            Exiv2::XmpKey k(key);
            auto& xm = image->xmpData();
            auto it = xm.findKey(k);
            if (it != xm.end()) return val(it->toString());
        }
        return val::null();
    } catch (const std::exception& e) {
        EM_ASM({ console.error('readTagText() exception:', UTF8ToString($0)); }, e.what());
        return val::null();
    }
}

val readTagBytes(val u8, const std::string& key) {
    try {
        auto bytes = toBytes(u8);
        auto image = openFromMemory(bytes);
        if (!image) return val::null();
        Exiv2::XmpParser::initialize();
        image->readMetadata();

        const Exiv2::Value* pv = nullptr;
        if (key.rfind("Exif.", 0) == 0) {
            Exiv2::ExifKey k(key);
            auto& ex = image->exifData();
            auto it = ex.findKey(k);
            if (it != ex.end()) pv = &it->value();
        } else if (key.rfind("Iptc.", 0) == 0) {
            Exiv2::IptcKey k(key);
            auto& ip = image->iptcData();
            auto it = ip.findKey(k);
            if (it != ip.end()) pv = &it->value();
        } else if (key.rfind("Xmp.", 0) == 0) {
            Exiv2::XmpKey k(key);
            auto& xm = image->xmpData();
            auto it = xm.findKey(k);
            if (it != xm.end()) pv = &it->value();
        } else {
            return val::null();
        }

        if (!pv) return val::null();

        std::string s = pv->toString();   // "65 0 66 0 ..." 등
        std::istringstream iss(s);
        int n;
        std::vector<unsigned char> out;
        while (iss >> n) {
            if (0 <= n && n <= 255) out.push_back(static_cast<unsigned char>(n));
        }
        if (out.empty()) return val::null();
        return toUint8Array(out);
    } catch (const std::exception& e) {
        EM_ASM({ console.error('readTagBytes() exception:', UTF8ToString($0)); }, e.what());
        return val::null();
    }
}

static val flushToBytes(Exiv2::Image::UniquePtr& image) {
    Exiv2::BasicIo& io = image->io();
    const size_t n = io.size();
    std::vector<unsigned char> out(n);
    io.seek(0, Exiv2::BasicIo::beg);
    io.read(reinterpret_cast<Exiv2::byte*>(out.data()), n);
    return toUint8Array(out);
}

val writeString(val u8, const std::string& key, const std::string& value) {
    try {
        auto bytes = toBytes(u8);
        auto image = openFromMemory(bytes);
        if (!image) return val::null();
        Exiv2::XmpParser::initialize();
        image->readMetadata();

        if      (key.rfind("Exif.", 0) == 0) { image->exifData()[key] = value; }
        else if (key.rfind("Iptc.", 0) == 0) { image->iptcData()[key] = value; }
        else if (key.rfind("Xmp.",  0) == 0) { image->xmpData()[key]  = value; }
        else { return val::null(); }

        image->writeMetadata();
        return flushToBytes(image);
    } catch (const std::exception& e) {
        EM_ASM({ console.error('writeString() exception:', UTF8ToString($0)); }, e.what());
        return val::null();
    }
}

val writeBytes(val u8, const std::string& key, val data /* Uint8Array */) {
    try {
        auto bytes = toBytes(u8);
        auto image = openFromMemory(bytes);
        if (!image) return val::null();
        Exiv2::XmpParser::initialize();
        image->readMetadata();

        auto raw = toBytes(data);
        Exiv2::Value::UniquePtr v = Exiv2::Value::create(Exiv2::unsignedByte);
        v->read(reinterpret_cast<const Exiv2::byte*>(raw.data()), (long)raw.size(), Exiv2::littleEndian);

        if      (key.rfind("Exif.", 0) == 0) { image->exifData()[key] = *v; }
        else if (key.rfind("Iptc.", 0) == 0) { image->iptcData()[key] = *v; }
        else if (key.rfind("Xmp.",  0) == 0) { image->xmpData()[key]  = *v; }
        else { return val::null(); }

        image->writeMetadata();
        return flushToBytes(image);
    } catch (const std::exception& e) {
        EM_ASM({ console.error('writeBytes() exception:', UTF8ToString($0)); }, e.what());
        return val::null();
    }
}

EMSCRIPTEN_BINDINGS(exiv2_wasm_min) {
    function("read",         &read);
    function("readTagText",  &readTagText);
    function("readTagBytes", &readTagBytes);
    function("writeString",  &writeString);
    function("writeBytes",   &writeBytes);
}
