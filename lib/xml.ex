defmodule XML do
  @moduledoc """
  An XML document parser designed for retrieving data from an XML API response.

  Wraps a subset of Erlang's xmerl module.
  http://erlang.org/doc/man/xmerl.html
  """

  import Record

  @doc """
  Import the xmlElement record from xmerl.

  It is the type that is returned when xmerl parses an XML document. It can be
  navigated with the xmerl xpath function. It has the following spec from the
  Erlang documentation.

  %% XML Element
  %% content = [#xmlElement()|#xmlText()|#xmlPI()|#xmlComment()|#xmlDecl()]
  -record(xmlElement,{
      name,      % atom()
      expanded_name = [],  % string() | {URI,Local} | {"xmlns",Local}
      nsinfo = [],          % {Prefix, Local} | []
      namespace=#xmlNamespace{},
      parents = [],    % [{atom(),integer()}]
      pos,      % integer()
      attributes = [],  % [#xmlAttribute()]
      content = [],
      language = "",  % string()
      xmlbase="",           % string() XML Base path, for relative URI:s
      elementdef=undeclared % atom(), one of [undeclared | prolog | external | element]
    }).
  """
  defrecord :xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")

  @doc """
  Import the xmlNamespace record from xmerl.

  This type will be returned when a XML Namespace element is selected with xpath/2 or get/2.
  An error message will be thrown in either case, because there is no value associated with a Namespace element. It has the following spec from the Erlang documentation.

  %% namespace record
  -record(xmlNamespace,{
	default = [],
	nodes = []
	}).
  """
  defrecord :xmlNamespace, extract(:xmlNamespace, from_lib: "xmerl/include/xmerl.hrl")

  @doc """
  Import the xmlText record from xmerl.

  It is the type that is returned when accessing the content attribute of
  an :xmlElement. It has the following spec from the Erlang documentation.

  %% plain text
  -record(xmlText,{
      parents = [],  % [{atom(),integer()}]
      pos,    % integer()
      language = [],% inherits the element's language
      type = text   % atom() one of (text|cdata)
    }).
  """
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  @typedoc """
  Erlang xmerl xmlElement.
  """
  @type xml_element :: :xmlElement
  defmacro is_xml_element(element) do
    quote do: is_record(unquote(element), :xmlElement)
  end

  @typedoc """
  Erlang xmerl xmlNamespace.
  """
  @type xml_namespace :: :xmlNamespace
  defmacro is_xml_namespace(element) do
    quote do: is_record(unquote(element), :xmlNamespace) 
  end

  @typedoc """
  Erlang xmerl xmlText.
  """
  @type xml_text :: :xmlText
  defmacro is_xml_text(element) do
    quote do: is_record(unquote(element), :xmlText)
  end

  @typedoc """
  Represents an XML tag name.

  It can be either a string, a character list.
  """
  @type tag :: String.t | list

  @typedoc """
  Represents an XML value.

  It can be either a string, a character list.
  """
  @type value :: String.t | list

  @typedoc """
  Raw XML data in the form of a string or char list.
  """
  @type xml :: String.t | list
  defmacro is_xml(xml) do
    quote do: is_bitstring(unquote(xml)) or is_list(unquote(xml))
  end

  

  @doc """
  Parses an XML document.

  It will take a char list or string representation of an XML document.  It
  returns an xmlElement that can be used for accessing values.

  Some schema validation occurs. If there is a DTD it will be strictly
  evaluated. If an error is ecnountered the process will exit and pass a
  message.

  ## Examples

    iex>XML.parse('<tag>value</tag>')
    {:xmlElement, :tag, :tag, [], {:xmlNamespace, [], []}, [], 1, [],
    [{:xmlText, [tag: 1], 1, [], 'value', :text}], [],
    '.', :undeclared }

    iex>XML.parse("<tag>value</tag>")
    {:xmlElement, :tag, :tag, [], {:xmlNamespace, [], []}, [], 1, [],
    [{:xmlText, [tag: 1], 1, [], 'value', :text}], [],
    '.', :undeclared }

    iex>try do
    ...>  XML.parse('<tag>value</stag>')
    ...>catch
    ...>  :exit, message ->
    ...>    message
    ...>end
    {:fatal, {{:endtag_does_not_match, {:was, :stag, :should_have_been,
    :tag}}, {:file, :file_name_unknown}, {:line, 1}, {:col, 14}}}
  """

  @spec parse(list) :: xml_element
  def parse(xml) when is_list(xml) do
    { parsed_xml, _ } = :xmerl_scan.string(xml)
    strip_path_data(parsed_xml)
  end
  @spec parse(String.t) :: xml_element
  def parse(xml) when is_bitstring(xml) do
    { parsed_xml, _ } = :xmerl_scan.string(:binary.bin_to_list(xml))
    strip_path_data(parsed_xml)
  end

  @doc """
  Returns value(s) associated with `tag` in `xml_element`.

  It takes either a parsed `xml_element` or `xml`(raw XML), and a `tag` to
  search for. A list of matching value(s) in the respective `xml` type will be
  returned.

  Both the `xml` and the `tag` will be assesed for corectness. If an invalid
  character is used in the `tag` it will exit with an :invalid_name error.

  ## Examples

      iex>XML.get('<bag>cat</bag>', 'bag')
      ['cat']

      iex>element = XML.parse('<bag>cat</bag>')
      ...>XML.get(element, 'bag')
      ['cat']

      iex>element = XML.parse('<bag>cat</bag>')
      ...>XML.get(element, "bag")
      ["cat"]

      iex>element = XML.parse('<bag>cat</bag>')
      ...>try do
      ...>  XML.get(element, '/bag')
      ...>catch
      ...>  :exit, message ->
      ...>    message
      ...>end
      {:fatal, {{:invalid_name, '/bag><'}, {:file, :file_name_unknown}, {:line,
      1}, {:col, 2}}}
  """
  @spec get(xml, tag) :: list | String.t 
  def get(xml, tag) when is_xml(xml) do
    parse(xml)
    |> get(tag)
  end
  @spec get(xml_element, tag) :: list | String.t
  def get(xml_element, tag) when is_list(tag) do
    _get(xml_element, tag)
  end
  def get(xml_element, tag) when is_bitstring(tag) do
    _get(xml_element, String.to_char_list(tag))
    |> Enum.map(&(List.to_string(&1)))
  end

  @spec _get(xml_element, tag) :: list
  defp _get(xml_element, tag) do
    validate_tag(tag)
    case _xpath(xml_element, '//' ++ tag )
      |> value_from_element do
      [ head | _ ] when is_xml_namespace(head) ->
        []
      values ->
        values
    end
    #|> content
    #|> text_value
    #|> value_from_element
  end

  @doc """
  Evaluate an `xml_element` with an XPath expression.

  It takes an XPath expression in the form of char list or string, and returns a
  list of any matching values in the respective type. If the expression uses
  characters that are not permitted by Xpath it will exit with :invalid_name
  error.

  ## Examples

      iex>element = XML.parse('<fun><bag>cat</bag><bag>brown</bag></fun>')
      iex>XML.xpath(element, '/bag') 
      nil
      iex>XML.xpath(element, '/fun/bag')
      ['cat', 'brown']
  """
  @spec xpath(xml_element, list) :: list
  def xpath(xml_element, path) when is_list(path) do
    case _xpath(xml_element, path)
    |> value_from_element do
      [] ->
        nil
      [ head | _ ] when is_xml_namespace(head) ->
        []
      values ->
        values
    end
  end
  def xpath(xml_element, path) when is_bitstring(path) do
    xpath(xml_element, String.to_char_list(path))
    |> Enum.map(fn value -> to_string(value) end)
  end

  @spec _xpath(xml_element, list) :: [xml_element]
  defp _xpath(xml_element, xpath) do
    :xmerl_xpath.string(xpath, xml_element)
  end

  @spec value_from_element([]) :: []
  defp value_from_element([]), do: []
  @spec value_from_element([ xml_element | xml_text | xml_namespace ]) :: [value]
  defp value_from_element(elements) do
    
    [ element | _ ] = elements
    cond do
      is_xml_namespace(element) ->
        raise "unhandled namespace **********"
      is_xml_text(element) ->
        text_value(elements)
      is_xml_element(element) ->
        content(elements)
        |> text_value
    end
  end


  @doc """
  Creates a map of `tag`/`value`s from a list of `tag`s

  If a `tag` doesn't exist it's corresponding value will be nil.
  If a `tag` has multiple values only the first will be paired with the `tag`.

  ## Examples

  """
  @spec to_map(xml, [tag]) :: [value]
  def to_map(xml, tags) when is_xml(xml) do
    parse(xml)
    |> to_map(tags)
  end
  @spec to_map(xml_element, [tag]) :: [value]
  def to_map(xml_element, [ head | tail ]) when is_bitstring(head) do
    tags = Enum.map([head | tail], &(String.to_char_list(&1)))
    to_map(xml_element, tags)
    |> map_to_bitstring
  end
  @spec to_map(xml_element, [tag]) :: [value]
  def to_map(xml_element, tags) when is_list(tags) do
    for key <- tags, into: %{ } do
      case xpath(xml_element, '//' ++ key) do
        nil ->
          { key, nil }
        [ ] ->
          { key, to_map(xml_element, get_children(xml_element, key)) }
        [ head | _ ] ->
          { key, head }
      end
    end
  end

  @spec map_to_bitstring(%{list => list}) :: %{String.t => String.t}
  def map_to_bitstring(tag_map) do
    for {k, v} <- tag_map, into: %{} do
      if is_list(v) do
        {to_string(k), to_string(v)}
      else
        {to_string(k), map_to_bitstring(v)}
      end
    end
  end

  @spec get_children(xml_element, tag) :: [tag]
  def get_children(xml_element, tag) when is_list(tag) do
    path = '/' ++ tag ++ '/child::node()'
    _xpath(xml_element, path)
    |> Enum.map(&(xmlElement(&1, :name))) 
    |> Enum.map(&(Atom.to_char_list(&1)))
  end
  def get_children(xml_element, tag) when is_bitstring(tag) do
    path = '/' ++ String.to_char_list(tag) ++ '/child::node()'
    _xpath(xml_element, path)
    |> Enum.map(&(xmlElement(&1, :name))) 
    |> Enum.map(&(Atom.to_string(&1)))
  end

  @spec content([xml_element]) :: [xml_text]
  defp content(xml_element) do
    check_for_namespace(xml_element)
    Enum.flat_map(xml_element, &(xmlElement(&1, :content)))
  end

  @spec get_keys([ xml_text ]) :: [String.t]
  defp get_keys(elements) do
    Enum.map(elements, &(xmlText(&1, :value)))
  end

  @spec text_value([ xml_text ]) :: [String.t]
  defp text_value(elements) do
    [ head | _ ] = elements
    tony = Enum.map(elements, &(xmlText(&1, :value)))
    Enum.map(elements, &(xmlText(&1, :value)))
  end

  # Remove verbose path data from xml_element xml_base attribute for easy testing
  # and readability.
  @spec strip_path_data(xml_element) :: xml_element
  defp strip_path_data(xml_element) do
    if elem(xml_element, 10) == cwd do
      put_elem(xml_element, 10, '.')
    else
      xml_element
    end
  end

  # Use :xmerl_scan to check if tag name is valid.
  @spec validate_tag(tag) :: xml_element | :exit
  defp validate_tag(tag) do
    :xmerl_scan.string('<#{tag}></#{tag}>')
  end

  @spec check_for_namespace([xml_element] | [xml_namespace] | [xml_text] | [list]) :: [] | [list]
  defp check_for_namespace([ head | _ ]) do
    if is_xml_namespace(head) do
      #raise "#{tag} is an XML Namespace element, which doesn't have a value."
      raise "xml Namespace element boooh!"
    end
    head 
  end

  @spec cwd :: list
  defp cwd do
    String.to_char_list(Path.absname(''))
  end
end
