# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
selectedCompiler = undefined
web3js = undefined
exampleContract = 'pragma solidity ^0.4.5;\n\
\n\
contract HelloWorld {\n\
\tfunction displayMessage() constant returns (string) {\n\
\t\treturn "Whale hello there!";\n\
\t}\n\
}'

changeStatusLabel = (txt, status = 'warning') ->
  $('#status').html(txt)
  $('#status').removeClass('alert-danger')
              .removeClass('alert-warning')
              .removeClass('alert-success')
              .addClass('alert-' + status)
  if txt.length
    $('#status').removeClass('hidden')
  else
    $('#status').addClass('hidden')

renderFunctionHashes = (hashes) ->
  output = ''
  $.each Object.keys(hashes), (index, func) ->
    output += (index+1) + ". " + hashes[func] + ": " + func + " \n"

  return output

renderContractsList = (contracts) ->
  $('#complied-contracts').html('');

  $.each contracts, (name, contract) ->
    $('#complied-contracts').append('
    <div class="panel panel-default"> \
      <div class="panel-heading" role="tab" id="contract' + name + '"> \
        <h4 class="panel-title"> \
          <a class="collapsed" role="button" data-toggle="collapse" data-parent="#compiled-contracts" href="#collapse'  +name + '" aria-expanded="false" aria-controls="collapse' + name + '"> \
            ' + name + ' \
          </a> \
          <span class="pull-right">Gas Estimate: <span class="badge">' + contract.gasEstimates.creation + '</span></span>
        </h4> \
      </div> \
      <div id="collapse' + name + '" data-name="'+name+'" class="panel-collapse collapse" role="tabpanel" aria-labelledby="contract' + name + '"> \
        <div class="panel-body"> \
          <h3>Bytecode:</h4>
          <textarea id="bytecode" class="form-control" readonly rows="2">' + contract.bytecode + '</textarea>
          <h3>ABI:</h4>
          <textarea id="interface" class="form-control" readonly rows="2">' + contract.interface + '</textarea>
          <h3>Function Hashes:</h4>
          <textarea class="form-control" readonly rows="2">' + renderFunctionHashes(contract.functionHashes) + '</textarea>
          <h3>Opcodes:</h4>
          <textarea class="form-control" readonly rows="2">' + contract.opcodes + '</textarea>

          <a class="btn btn-success" id="deploy-btn" href="#" data-target="collapse' + name + '">Deploy contract</a>
        </div> \
      </div> \
    </div> \
    ');


deployContract = (name, bytecode, abi) ->
  if typeof web3 == 'undefined'
    bootbox.alert({message: 'No web3? You should consider trying MetaMask!'})
    return

  web3js = new Web3(web3.currentProvider);

  web3js.eth.getAccounts (err, accounts) ->
    if err != null
      changeStatusLabel('There was an error accessing your accounts: ' + err, 'danger')
      return

    if accounts.length == 0
      bootbox.alert({message: 'Could not get list of accounts. Please check your MetaMask is probably locked'})
      return

    bootbox.confirm 'Please confirm the publication of the smart contract '+name+ ' on the network!', (result) ->
      return unless result

      contract = web3js.eth.contract(abi)
      params = { from: accounts[0], data: bytecode, gas: 1000000 }
      contractInstance = contract.new params, (err, res) =>
          if err
            bootbox.alert({
                message: 'Error: ' + err
            })
            return

          if res.address
             bootbox.dialog(
              title: 'Success deployed contract ' + name
              message: '<p>You contract has successful deployer to network.</p>'
              buttons:
                cancel:
                  label: 'Close'
                open:
                  label: 'Open contract in new tab'
                  className: 'btn-info',
                  callback: ->
                    window.open('https://rinkeby.etherscan.io/address/' + res.address,'_blank');
                    return
            )
          else
             bootbox.dialog(
              title: 'Transaction successfully sent to the network'
              message: '<p>The transaction for publishing a smart contract on the network was successfully created, wait for confirmation from the network.</p>'
              buttons:
                cancel:
                  label: 'Close'
                open:
                  label: 'Open transaction in new tab'
                  className: 'btn-info',
                  callback: ->
                    window.open('https://rinkeby.etherscan.io/tx/' + res.transactionHash,'_blank');
                    return
            )

solidityCompile = ->
  unless selectedCompiler
    return

  changeStatusLabel('Compiling...')

  $('#bytecode, #interface, #functionHashes, #opcodes').val('')
  result = selectedCompiler.compile($('#source').val(), 1)
  if result.errors
    bootbox.alert({
        message: "Errors:\n" + result.errors.join("\n")
    })
    return

  if result.formal.errors
    changeStatusLabel("Contract was successfully compiled... <br>Warnings:<br>" + result.formal.errors.join("<br>"), 'warning')
    renderContractsList(result.contracts)
  else
    changeStatusLabel('Contract was successfully compiled...', 'success')

loadSolidityCompilerVersion = ->
  changeStatusLabel('Loading Solidity Compiler: ' + $('#versions').val())
  BrowserSolc.loadVersion $('#versions').val(), (compiler) ->
    selectedCompiler = compiler
    changeStatusLabel('Solidity Compiler loaded. Ready to Compiling...', 'success')


window.onload = ->
  $('#source').val(exampleContract);
  $('#versions').change ->
    loadSolidityCompilerVersion()

  $('#compile-btn').click ->
    solidityCompile()

  $(document).on 'click', '#deploy-btn', (e) ->
    e.preventDefault()

    contract = $('#'+$(this).data('target'))

    deployContract(contract.data('name'), contract.find('#bytecode').val(), JSON.parse(contract.find('#interface').val()) )

  if typeof BrowserSolc == 'undefined'
    changeStatusLabel('You have to load browser-solc.js in the page.', 'danger')
    throw new Error

  changeStatusLabel('Loading Compiler....')

  BrowserSolc.getVersions (solSources, solReleases) ->
    $.each solSources, (i, value) ->
      $('#versions').append($("<option></option>").attr('value', value).text(value));
    $('#versions').val(solReleases['0.4.5'])

    loadSolidityCompilerVersion()
