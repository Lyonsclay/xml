defmodule XMLTest do
  use ExUnit.Case
  import XML
  import Record
  doctest XML

  test "parse a well-formed XML list" do
    xml = parse('<xml>this</xml>')
    assert(is_record(xml, :xmlElement))
  end

  test "parse a well-formed XML string" do
    xml = parse("<xml>this</xml>")
    assert(is_record(xml, :xmlElement))
  end

  test "parse poorly formed XML data" do
    catch_exit(parse('<x>this</xml>'))
  end

  test "get a value from XML data" do
    element = parse('<bag>cat</bag>')

    assert(get(element, 'bag') == ['cat'])
    assert(get(element, "bag") == ["cat"])
    assert(get(element, :bag) == [:cat])
  end

  test "get multiple values from XML data" do
    element = parse('<fun><bag>cat</bag><bag>brown</bag></fun>')

    assert(get(element, 'bag') == ['cat', 'brown'])
    assert(get(element, './/fun/bag') == ['cat', 'brown'])
  end
end
