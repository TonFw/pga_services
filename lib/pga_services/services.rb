module PGA
  # SetUp vars
  PGA = YAML.load_file("#{File.dirname(__FILE__)}/configs/services.yml").it_keys_to_sym

  class Services
    @farmer_cpf
    @@instance
    attr_accessor :current_gta

    def self.get_instance
      @@instance.nil? ? @@instance = PGA::Services.new : @@instance
    end

    # Para listar as funcionalidades: @client.operations
    def initialize
      # Create the base URL
      @url = "#{PGA[:protocol]}://#{PGA[:domain]}/#{PGA[:path]}"
      @services = PGA[:services]

      # Criação e configuração dos Clientes Savon
      @client_cna = create_client_pga ws_url(:wsdl_url_cna_card)
      @client_protocolo = create_client_pga ws_url(:wsdl_url_protocols_query)
      @client_gta = create_client_pga ws_url(:wsdl_url_gta)
      @client_earrings_gtas = create_client_pga ws_url(:wsdl_url_earring_gtas)
      @client_no_contact_property = create_client_pga ws_url(:wsdl_url_prop_sem_contato)
      @client_slaughterhouse = create_client_pga ws_url(:wsdl_url_slaughterhouse)
      @client_farmer_email = create_client_pga ws_url(:wsdl_url_produtor_email)
      @client_geoloc = create_client_pga ws_url(:wsdl_url_geoloc)
    end

    def ws_url service
      "#{@url}/#{@services[service]}"
    end

    def auth_pga email, password
      crypt = Base64.strict_encode64("#{email}:#{password}")

      @client_usuario = Savon.client(
          wsdl: WSDL_URL_PROTOCOLOS_QUERY,
          namespace: 'http://www.ibm.com/maximo',
          namespace_identifier: nil,
          convert_request_keys_to: :none,
          soap_header: { 'Authorization' => "Basic #{crypt}" },
          pretty_print_xml: true,
          log: true
      )
    end

    def connected?
      # return false if @client.nil? else return true
      @client_cna.nil? ? false : true
      @client_protocolo.nil? ? false : true
    end

    # Cria um cliente PGA de forma facilitada
    def create_client_pga url
      crypt_senha_root = Base64.strict_encode64("maxadmin:123456")

      return Savon.client(
          wsdl: url,
          namespace: 'http://www.ibm.com/maximo',
          namespace_identifier: nil,
          convert_request_keys_to: :none,
          soap_header: { 'Authorization' => "Basic #{crypt_senha_root}" },
          pretty_print_xml: true,
          log: false
      )
    end

    # Exploração Bovina do produtor corrente
    def get_farms farmer_cpf, validate_sisbov = false
      # 04 é a exploração
      query = "id2tipolocal=04 AND exists (select 1 from id2locationusercust where personid='#{farmer_cpf}' AND location=locations.location)"
      query = query + " AND maadesao=1" if validate_sisbov
      @exploracoes = @client_cna.call(:query_locations, message: { LOCATIONSQuery: { WHERE: query } })
      locations_set = @exploracoes.body[:query_locations_response][:locations_set]
      locations_set.nil? ? nil : locations_set[:locations]
      #locations_set.nil? ? nil : locations_set[:locations]
    end

    # Todos dados cadastrais da Propriedade e seu Dono
    def get_property cod_prop, validate_sisbov = false
      # 01 é a propriedade
      query = "location='#{cod_prop}'"
      query = query + " AND id2eras=1" if validate_sisbov
      @propriedades = @client_cna.call(:query_locations, message: { LOCATIONSQuery: { WHERE: query } })
      locations_set = @propriedades.body[:query_locations_response][:locations_set]
      locations_set.nil? ? nil : locations_set[:locations]
    end

    def get_active_earrings farm_code
      # Status define se está indo ser entregue (EM TRANSITO) ou já com o proprietário (EM USO)
      query = "status='EM USO' AND maestratificacao IS NOT NULL AND location='#{farm_code}'"
      @exploracao = @client_protocolo.call(:query_asset, message: { ASSETQuery: { WHERE: query } })
      asset_set = @exploracao.body[:query_asset_response][:asset_set]
      animals = asset_set[:asset] unless asset_set.nil?
      animals = [animals] if animals.is_a?Hash
      asset_set.nil? ? [] : animals
    end

    def get_inactive_earrings farm_code
      # Status define se está indo ser entregue (EM ESTOQUE) ou já com o proprietário (EM USO)
      query = "status='EM ESTOQUE' AND maestratificacao IS NULL AND location='#{farm_code}'"
      @exploracao = @client_protocolo.call(:query_asset, message: { ASSETQuery: { WHERE: query } })
      asset_set = @exploracao.body[:query_asset_response][:asset_set]
      animals = asset_set[:asset] unless asset_set.nil?
      animals = [animals] if animals.is_a?Hash
      asset_set.nil? ? [] : animals
    end

    # Recupera as explorações da mesma propriedade de uma outra exploração
    def sister_farms cod_prop, validate_sisbov = false
      # 01 é a propriedade e 04 é exploração
      query = "id2tipolocal=04 AND id2codprop='#{cod_prop}'"
      query = query + " AND maadesao=1" if validate_sisbov
      @exploracoes = @client_cna.call(:query_locations, message: { LOCATIONSQuery: { WHERE: query } })
      locations_set = @exploracoes.body[:query_locations_response][:locations_set]
      locations_set.nil? ? nil : locations_set[:locations]
    end

    # Pegas as GTAs envolvidas entre CPFs (Produtores)
    def get_gtas_farmer_farmer farmer_cpf, farm_code
      # Query de busca pelo CPF e Cod_Eploracao
      query_recebidas = "(ID2DESEXPCOD = '#{farm_code}' AND ID2DESEXPPER = '#{farmer_cpf}' AND STATUS NOT IN ('GRAVADA'))"
      query_enviadas = "(ID2PROEXPCOD = '#{farm_code}' AND ID2PROEXPPER = '#{farmer_cpf}' AND STATUS NOT IN ('GRAVADA'))"

      @gtas_recebidas = @client_gta.call(:query_mxgtacnacard, message: { MXGTACNACARDQuery: { WHERE: query_recebidas } })
      @gtas_enviadas = @client_gta.call(:query_mxgtacnacard, message: { MXGTACNACARDQuery: { WHERE: query_enviadas } })

      mx_gta_cnacard_recebidas = @gtas_recebidas.body[:query_mxgtacnacard_response][:mxgtacnacard_set]
      mx_gta_cnacard_enviadas = @gtas_enviadas.body[:query_mxgtacnacard_response][:mxgtacnacard_set]

      retorno_recebidas = []
      retorno_enviadas = []

      if mx_gta_cnacard_recebidas.nil? then retorno_recebidas = { erro: 'sem_recebidas' } else retorno_recebidas << mx_gta_cnacard_recebidas[:po] end
      if mx_gta_cnacard_enviadas.nil? then retorno_enviadas = { erro: 'sem_enviadas' } else retorno_enviadas << mx_gta_cnacard_enviadas[:po] end

      if mx_gta_cnacard_recebidas.nil? && mx_gta_cnacard_enviadas.nil?
        retorno_recebidas = { erro: 'CPF ou CodPropriedade inválidos' }
        retorno_enviadas = { erro: 'CPF ou CodPropriedade inválidos' }
      end

      retorno = {}
      retorno[:gtas_recebidas] = retorno_recebidas
      retorno[:gtas_enviadas] = retorno_enviadas

      retorno
    end

    # Pegas as GTAs envolvidas p/ propriedade rural
    def get_property_gtas cod_prop
      # Query de busca pelo CodProp
      query_recebidas = "(ID2DESEXPPROP = '#{cod_prop}' AND STATUS NOT IN ('GRAVADA'))"

      # GTAs complete Response
      @gtas_recebidas = @client_gta.call(:query_mxgtacnacard, message: { MXGTACNACARDQuery: { WHERE: query_recebidas } })

      # MX GTA (only the attrs)
      mx_gta_cnacard_recebidas = @gtas_recebidas.body[:query_mxgtacnacard_response][:mxgtacnacard_set]

      # Prepair what to return
      if mx_gta_cnacard_recebidas.nil? then retorno_recebidas = { erro: 'sem_recebidas' } else retorno_recebidas = mx_gta_cnacard_recebidas[:po] end
      return retorno_recebidas
    end

    # Pegas as GTAs envolvidas no CPF p/ Abatedoro
    def get_gtas_farmer_slaughterhouse farmer_cpf, farm_code
      # Query de busca pelo CPF e Cod_Eploracao
      query = "(ID2PROEXPCOD = '#{farm_code}' AND ID2PROEXPPER = '#{farmer_cpf}' AND STATUS NOT IN ('GRAVADA'))"
      @gtas = @client_gta.call(:query_mxgtacnacard, message: { MXGTACNACARDQuery: { WHERE: query } })
      mx_gta_cnacard = @gtas.body[:query_mxgtacnacard_response][:mxgtacnacard_set]
      mx_gta_cnacard.nil? ? nil : mx_gta_cnacard[:po]
    end

    def get_gta_by_identifier serie, number, uf
      # Query de busca pelo CPF e Cod_Eploracao
      query = "(ID2SERIE='#{serie}' AND ID2NUMGTA='#{number}' AND ID2ADDUF='#{uf}')"
      @gtas = @client_gta.call(:query_mxgtacnacard, message: { MXGTACNACARDQuery: { WHERE: query } })
      mx_gta_cnacard = @gtas.body[:query_mxgtacnacard_response][:mxgtacnacard_set]
      return nil if mx_gta_cnacard.nil?
      gta = mx_gta_cnacard[:po]
      gta[:poline] = [gta[:poline]] if gta[:poline].is_a?Hash
      self.current_gta = gta
      return gta
    end

    def get_earring_transference_in_period earring, period
      # Query de busca pelo Brinco no Range do Periodo
      query = "assetnum='#{earring}' AND exists (SELECT 1 FROM postatus WHERE changedate BETWEEN sysdate-#{period} AND sysdate)"

      # GTAs from it earring
      @earrings_received = @client_earrings_gtas.call(:query_gta_brincos, message: { GTA_BRINCOSQuery: { WHERE: query } })
      gta_earrings = @earrings_received.body[:query_gta_brincos_response][:gta_brincos_set]
      gta_earrings.nil? ? [] : [gta_earrings[:matbtransani]] # Empty array means no earring transference, is the better scene
    end

    def time_without_gta codprop
      # Query de busca pelo Brinco no Range do Periodo
      query = "maestrurid='#{codprop}'"

      # Retrive it time
      counter_xml = @client_no_contact_property.call(:query_dias_sem_contato, message: { DIAS_SEM_CONTATOQuery: { WHERE: query } })
      counter_set = counter_xml.body[:query_dias_sem_contato_response][:dias_sem_contato_set]
      counter = counter_set[:matbcon] unless counter_set.nil?
      counter = {madiacontid:0,maestrurid:0,mamicregid:0} if counter_set.nil?
      return {days_counter:counter[:madiacontid].to_i, property:counter[:maestrurid].to_i, zone:counter[:mamicregid].to_i}
    end

    # Return the slaughterhouse based on it SIF
    def get_slaughterhouse_by sif
      query = "id2numcont='#{sif}'"

      begin
        slaughterhouse_xml = @client_slaughterhouse.call(:query_frigorifico, message:{ FRIGORIFICOQuery: { WHERE: query } })
        slaughterhouse_set = slaughterhouse_xml.body[:query_frigorifico_response][:frigorifico_set]
        slaughterhouse = slaughterhouse_set[:id2_vwloc02]
        cnpj = slaughterhouse[:person][:personid]
        name = slaughterhouse[:person][:displayname]
        sif = slaughterhouse[:id2_numcont]
        uf = State.where(symbol: slaughterhouse[:id2_adduf]).take.id
        return_hash = {cnpj: cnpj, name: name, sif: sif, uf: uf}
      rescue => e
        return_hash = {error:e.message}
      end

      # Person have it name & CNPJ
      return return_hash
    end

    # Return it produtor email
    def get_full_person cpf
      query = "personid='#{cpf}'"
      email_xml = @client_farmer_email.call(:query_person, message:{ PERSONQuery: { WHERE: query } })
      email_set = email_xml.body[:query_person_response][:person_set]
      email_set[:person][:email] = {emailaddress:nil} if email_set[:person][:email].nil?
      email_set.nil? ? {error:'CPF não encontrado na PGA'} : email_set[:person]
    end

    def get_geo_loc property_id, validate_sisbov = false
      # Campos úteis: ID2UTMLAT (Latitude) ID2UTMLON (Longitude)
      query = "location='#{property_id}'"
      query = query + " AND id2eras=1" if validate_sisbov
      @utm_geoposicionamento = @client_geoloc.call(:query_coordenadas, message: { COORDENADASQuery: { WHERE: query } })
      coordinate_set = @utm_geoposicionamento.body[:query_coordenadas_response][:coordenadas_set]
      coordinate_set.nil? ? {latitude:nil, longitude:nil} : {latitude:coordinate_set[:id2_cooext][:id2_utmlat], longitude:coordinate_set[:id2_cooext][:id2_utmlon]}
    end

    # GET the transported animals (it earrings) USING TAI WSDL
    def get_transported_animals maponum_gta_id
      # GTA.XXXXXXX.2014 is the AnimalTraffic(GTA) id on the PGA
      query = "ponum = '#{maponum_gta_id}'"

      animals_xml = @client_earrings_gtas.call(:query_gta_brincos, message: { GTA_BRINCOSQuery: { WHERE: query } })
      animals_set = animals_xml.body[:query_gta_brincos_response][:gta_brincos_set]
      return [] if animals_set.nil?
      animals = animals_set[:matbtransani]
      animals = [animals] unless animals.is_a? Array
      return animals
    end
  end

end