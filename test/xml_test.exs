defmodule XMLTest do
  use ExUnit.Case
  import XML
  import Record
  doctest XML

  test "parse a well-formed XML list" do
    xml = parse('<xml>this</xml>')
    assert is_record(xml, :xmlElement)
  end

  test "parse a well-formed XML string" do
    xml = parse("<xml>this</xml>")
    assert is_record(xml, :xmlElement)
  end

  test "parse poorly formed XML data" do
    catch_exit parse('<x>this</xml>')
  end

  test "get a value from XML data" do
    element = parse('<bag>cat</bag>')

    assert get(element, 'bag') == ['cat']
    assert get(element, "bag") == ["cat"]
    assert get(element, :bag) == [:cat]
  end

  test "get a non-existant value from XML data" do
    element = parse('<bag>cat</bag>')

    assert get(element, 'dog') == []
  end

  test "get with an illegal `tag` name" do
    element = parse('<bag>cat</bag>')

    catch_exit get(element, '1bag')
  end

  test "get multiple values from an XML element" do
    element = parse('<fun><bag>cat</bag><bag>brown</bag></fun>')

    assert get(element, 'bag') == ['cat', 'brown']
  end

  test "get a value from un-parsed XML" do
    xml = '<bag>cat</bag>'

    assert get(xml, 'bag') == ['cat']
  end

  test "retrieve value from XML data with xpath" do
    element = parse('<fun><bag>cat</bag><bag>brown</bag></fun>')

    assert xpath(element, '/fun/bag') == ['cat', 'brown']
    assert xpath(element, "/fun/bag") == ["cat", "brown"]
  end

  test "retrieve value with non-existant `tag` from xpath" do
    element = parse('<bag>cat</bag>')

    assert xpath(element, '/funny') == []
  end

  test "retrieve value with invalid XPath expression from xpath" do
    element = parse('<bag>cat</bag>')

    catch_exit xpath(element, "/%") == []
  end
end
