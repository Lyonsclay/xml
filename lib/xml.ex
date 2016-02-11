defmodule XML do
  @moduledoc """
  An XML document parser wrapping a subset of Erlang's xmerl module.  http://erlang.org/doc/man/xmerl.html

  Functions parse various representations of an XML document and produce an a record
  that is one of several xmerl Elements.
  Implementation of xpath on XML record.
  """

  import Record

  @doc """
  Import the xmlElement record from xmerl.

  This type is returned when xmerl parses an XML document. It can be
  navigated with the xmerl xpath function. It has the following spec from
  the Erlang documentation.
  
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
  Import the xmlText record from xmerl.

  This type is returned when accessing the content attribute of :xmlElement. It
  has the following spec from the Erlang documentation.

  %% plain text
  %% IOlist = [char() | binary () | IOlist]
  -record(xmlText,{
      parents = [],  % [{atom(),integer()}]
      pos,    % integer()
      language = [],% inherits the element's language
      value,  % IOlist()
      type = text   % atom() one of (text|cdata)
    }).
  """
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  @typedoc """
  Erlang xmerl xmlElement.
  """
  @type xml_element :: :xmlElement
 
  @typedoc """
  Erlang xmerl xmlText
  """
  @type xml_text :: :xmlText

  @type key :: String.t | list | atom

  @doc """
  Parses a list representation of an XML document.

  Some schema validation occurs. If there is a DTD it
  will be strictly evaluated.

  ## Examples

    iex>parse('<tag>value</tag>')
    {:xmlElement, :tag, :tag, [], {:xmlNamespace, [], []}, [], 1, [],
    [{:xmlText, [tag: 1], 1, [], 'value', :text}], [],
    '.', :undeclared }
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
  Returns value associated with `key` in `xml_element`.

  It takes a char list, string or atom and outputs the respective type.
  It will also take an xpath expression.
  """
  @spec get(xml_element, key) :: list | String.t
  def get(xml_element, key) when is_list(key) do
    _get(xml_element, key)
  end
  def get(xml_element, key) when is_bitstring(key) do
    _get(xml_element, String.to_char_list(key))
    |> Enum.map(&(List.to_string(&1)))
  end
  def get(xml_element, key) when is_atom(key) do
    _get(xml_element, Atom.to_char_list(key))
    |> Enum.map(&(List.to_atom(&1)))
  end

  @spec _get(xml_element, key) :: list
  def _get(xml_element, key) do
    _xpath(xml_element, '//' ++ key )
    |> content
    |> text_value
  end

  @spec _xpath(xml_element, list) :: [xml_element]
  defp _xpath(xml_element, xpath) do
    :xmerl_xpath.string(xpath, xml_element)
  end

  @spec content([xml_element]) :: [xml_text]
  defp content(xml_element) do
    Enum.flat_map(xml_element, &(xmlElement(&1, :content)))
  end

  @spec text_value(xml_text) :: [String.t]
  defp text_value(xml_text) do
    Enum.map(xml_text, &(xmlText(&1, :value)))
  end

  # Remove path data from xml_element xml_base attribute
  # for easy testing and interpretation.
  @spec strip_path_data(xml_element) :: xml_element
  defp strip_path_data(xml_element) do
    if elem(xml_element, 10) == cwd do
      put_elem(xml_element, 10, '.')
    else
      xml_element
    end
  end

  defp cwd do
    String.to_char_list(Path.absname(''))
  end
end
