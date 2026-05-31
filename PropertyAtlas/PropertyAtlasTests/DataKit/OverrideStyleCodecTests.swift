// PropertyAtlasTests/DataKit/OverrideStyleCodecTests.swift
import Testing
@testable import PropertyAtlas

struct OverrideStyleCodecTests {
    @Test func decodesPartial() {
        let o = OverrideStyleCodec.decode(##"{"shape":"diamond","size":28}"##)
        #expect(o.shape == "diamond")
        #expect(o.size == 28)
        #expect(o.fillHex == nil)
        #expect(o.labelVisible == nil)
    }

    @Test func encodeOmitsNil() throws {
        var o = OverrideStyle()
        o.fillHex = "#FF0000"
        let json = OverrideStyleCodec.encode(o)
        #expect(json != nil)
        #expect(try #require(json?.contains("fillHex")))
        #expect(try !(#require(json?.contains("shape"))))
    }

    @Test func encodeEmptyReturnsNil() {
        #expect(OverrideStyleCodec.encode(OverrideStyle()) == nil)
    }

    @Test func roundTrip() throws {
        var o = OverrideStyle()
        o.shape = "star"
        o.glyph = "★"
        o.labelVisible = true
        let json = try #require(OverrideStyleCodec.encode(o))
        let back = OverrideStyleCodec.decode(json)
        #expect(back.shape == "star")
        #expect(back.glyph == "★")
        #expect(back.labelVisible == true)
    }
}
