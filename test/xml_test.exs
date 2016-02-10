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
  
  end

  @tag :skip
  #test "receives an xml response body" do
  #  { :ok, string } = File.read("test/webster_response.xml")

  #  body = :binary.bin_to_list string

  #  { xml, _ } = :xmerl_scan.string body

  #  [ field | _ ] = :xmerl_xpath.string('//fl', xml)

  #  assert is_record(field, :xmlElement) == true

  #  IO.inspect field

  #  [ text ] = xmlElement(field, :content) 

  #  assert(is_record(text, :xmlText))

  #  assert is_record(text, :xmlText) == true

  #  part = xmlText(text, :value) 

  #  assert(part == 'noun')
  #end
end
