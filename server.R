##### 2 ) SERVER #####

function(input, output, session) {
  
  ##### 2.1 ) On Server Start #####
  #updateCollapse(session,id = "collapseQuery", close = "Network Inference")
  hide("nodeFlag")
  hide("arcsFlag")
  hide("dblClickFlag")
  hide("clickFlag")
  hide("clickDebug")
  hide('loading')
  hide("multiPurposeButton")
  hide("bnUpload")
  checked = list(edges=FALSE,data=FALSE)
  nodes = NULL
  edges = NULL
  data = NULL
  bn = NULL
  debug = FALSE
  debugCounter = 0
  queryRepeat = 19
  evidenceMenuUiInjected = FALSE
  shinyjs::runjs(
    "if(getCookie('BN_tutorial') != 'true'){
        // Clear previous step
       localStorage.removeItem('tour_current_step');
       localStorage.removeItem('tour_end');
    
        // Initialize the tour
        tour.init();
    
    
        // Start the tour
        tour.start(true);
    }"
  )
  
  ## 2.2 ) Plots #####
  
  #' Plot the distribution of a target node.
  #' 
  #' @param withEvidence if evidence is set, prob is 0% 0% ... 100% ... 0% 0%
  #' @examples
  #' nodePlot(withEvidence = TRUE)
  nodePlot <- function(withEvidence = FALSE){
    if(!is.null(input$current_node_id)){
      nodeInfo = getNodeInfo(input$current_node_id)
      nodeName = nodeInfo$name
      if(withEvidence){
        choices = nodeInfo$choices[-1]
        prob = rep(0,length(choices))
        names(prob) = choices
        prob[nodeInfo$evidence]=1
      } else {
        s = table(rbn(bn, n = 5000, debug = FALSE)[as.character(nodeInfo$name)])
        for(i in 1:4){
          s = rbind(s,table(rbn(bn, n = 5000, debug = FALSE)[as.character(nodeInfo$name)]))
        }
        s = colMeans(s)
        prob = s/sum(s)
      }
      labels = names(prob)
      srt = 0
      offset = 0
      if(length(labels)>3) {
        srt = 25
        offset = 0.1
      }
      x<-barplot(prob/sum(prob),
              col = rainbow(n = length(prob), s = 0.5),
              main = toupper(nodeName), xaxt='n',
              ylim=c(0,1))
      text(x, prob+0.05, paste(round(prob*100), "%", sep="") ,cex=1, font = 2, col = rainbow(n = length(prob), s = 0.5)) 
      text(x=x-offset, y=-0.1, labels = names(prob), cex=1, xpd=TRUE, srt=srt)
    }
    hideLoading(modal=TRUE)
  }
  
  #' Plot the posterior distribution of a target query node.
  #' 
  #' @param data the outcoming probabilities of the query
  #' @examples
  #' queryData = table(cpdist(bn, queryNode, queryEvidence))
  #' queryPlot(data= queryData)
  #' @seealso \code{\link[bnlearn]{cpdist}} for the query data format
  queryPlot <- function(data){
    nodeInfo = getNodeInfo(nodes[which(nodes$label == input$nodeToQuery),]$id)
    s = table(rbn(bn, n = 5000, debug = FALSE)[as.character(nodeInfo$name)])
    for(i in 1:4){
      s = rbind(s,table(rbn(bn, n = 5000, debug = FALSE)[as.character(nodeInfo$name)]))
    }
    s = colMeans(s)
    prob = s/sum(s)
    par(mfrow=c(1,2))
    labels = names(prob)
    srt = 0
    offset = 0
    if(length(labels)>3) {
      srt = 25
      offset = 0.1
    }
    output = prob/sum(prob)
    x<-barplot(output,
            col = rainbow(n = length(output), s = 0.5),
            ylim=c(0,1), xaxt='n',
            main = paste("P(",toupper(input$nodeToQuery),")"))
    text(x, output+0.05, paste(round(output*100), "%", sep="") ,cex=1, font = 2, col = rainbow(n = length(output), s = 0.5)) 
    text(x=x-offset, y=-0.1, labels = names(output), cex=1, xpd=TRUE, srt=srt)
    output = data/sum(data)
    x2<-barplot(output,
            col = rainbow(n = length(output), s = 0.5),
            ylim=c(0,1), xaxt='n',
            main = paste("P(",toupper(input$nodeToQuery),"| EVIDENCE )"))
    text(x2, output+0.05, paste(round(output*100), "%", sep="") ,cex=1, font = 2, col = rainbow(n = length(output), s = 0.5)) 
    text(x=x2-offset, y=-0.1, labels = names(output), cex=1, xpd=TRUE, srt=srt)
    hideLoading(query = TRUE)
  }
  
  ##### 2.3 ) Network #####
  
  #' Render the bayesian network. 
  #' Click and DblClick events chenge flags values triggering external actions.
  #' GravitationalConstant in \code{\link[visPhysics]{visPhysics}} can be changed to shrink/expand the network when rendering
  #' 
  #' @examples
  #' queryData = table(cpdist(bn, queryNode, queryEvidence))
  #' queryPlot(data= queryData)
  #' @seealso \code{\link[visNetwork]} for a detailed description of the rendering process
  visNetworkRenderer = function(){
    visNetwork(nodes, parseEdges(edges,nodes)) %>%
      visNodes(shape = "ellipse") %>%
      visEdges(arrows = "to") %>%
      visOptions(collapse = FALSE, highlightNearest = FALSE) %>%
      visPhysics(stabilization = TRUE,
                 solver = "forceAtlas2Based",
                 forceAtlas2Based = list(gravitationalConstant = -40)) %>%
      visInteraction(navigationButtons = FALSE,dragView = TRUE) %>%
      visGroups(groupname = "evidence", color = "orange") %>%
      visEvents(doubleClick = "
        function(nodes) {
          Shiny.onInputChange('current_node_id', nodes.nodes);
          Shiny.setInputValue('dblClickFlag', 0)
          if(debugFlag) console.log(nodes.nodes)
        ;}",
                click = "
        function(nodes) {
          Shiny.onInputChange('current_node_id', nodes.nodes);
          Shiny.setInputValue('clickFlag', 0)
        ;}"    
      )
  }
  
  ##### 2.4 ) Observers #####
  
  #' When dblClickFlag value changes:
  #' Toggle the modal panel, update values of radio buttons with the values of the selected node and plot the distribution
  #' @seealso \code{\link{toggleModal}}, \code{\link{updateRadios}}, \code{\link{nodePlot}}, \code{\link{getNodeInfo}}
  observeEvent(input$dblClickFlag,{
    if(input$dblClickFlag == 0 && !is.null(input$current_node_id) && checked$data) {
      showLoading(modal=TRUE)
      nodeInfo = getNodeInfo(input$current_node_id)
      toggleModal(session, 'nodeModal', toggle = 'toggle')
      updateRadios(id=input$current_node_id)
      output$nodePlot <- renderPlot({nodePlot(nodeInfo$evidenceYN)})
    } 
    updateNumericInput(session,"dblClickFlag",value = 1)
  })
  
  #' When clickFlag value changes:
  #' Update the selected node in the sidebar's query menu
  #' @seealso \code{\link{getNodeInfo}} 
  observeEvent(input$clickFlag,{
    if(input$clickFlag == 0 && !is.null(input$current_node_id)) {
      updateSelectInput(session,"nodeToQuery",selected = getNodeInfo(input$current_node_id)$name)
    }
    updateNumericInput(session,"clickFlag",value = 1)
  })
  
  #JUST FOR DEBUGGING
  observeEvent(input$multiPurposeButton,{
    ## Put here the code you want to check
    shinyjs::runjs("console.log(Shiny.inputBindings);")
  })
  
  #' When evidenceMenuButton is clicked:
  #' Update the selected node in the sidebar's query menu
  #' @seealso \code{\link{getNodeInfo}}, \code{\link{updateEvidence}}
  observeEvent(input$evidenceMenuButton,{
    if(checked$data){
      lapply(1:length(nodes$id), function(i){
        id = nodes[i,]$id
        if(!evidenceMenuUiInjected){
          isolate({
            nodeInfo = getNodeInfo(id)
            insertUI(
              where = "beforeBegin",
              selector = "#evidenceControls",
              ui = tags$div(id="whocares",radioButtons(paste0("evidence_",id), label = toupper(nodeInfo$name), choices = nodeInfo$choices))
            )
          })}
        observeEvent(input[[paste0("evidence_",id)]],{
          updateEvidence(id,input[[paste0("evidence_",id)]])
        })
      })
      evidenceMenuUiInjected <<- TRUE
    }
    else {
      showNotification("The newtowrk is not fully-defined. Load the data or a pre-trained network first.", type = "warning")
    }
  })
  
  observeEvent(input$viewCPT,{
    if(!is.null(input$current_node_id)){
      nodeInfo = getNodeInfo(input$current_node_id)
      nodeName = nodeInfo$name
      table = as.data.frame(bn[[as.character(nodeName)]]$prob)
      table$Freq = paste0(round(table$Freq*100,digits = 1),"%")
      output$mytable = DT::renderDataTable({table}, editable = NULL)
      #output$mytable = DT::renderDataTable({table}, editable = list(target = 'cell', disable = list(columns = seq(ncol(table)-1))))
    }
  })
  
  proxy = dataTableProxy('mytable')
  
  observeEvent(input$mytable_cell_edit, {
    nodeInfo = getNodeInfo(input$current_node_id)
    nodeName = nodeInfo$name
    a = bn[[as.character(nodeName)]]$prob
    table = as.data.frame(a)
    info = input$mytable_cell_edit
    str(info)
    i = info$row
    j = info$col
    v = info$value
    row = table[i,]
    a[row$Var1]=as.numeric(v)
  })
  
  #' When clickDebug is clicked:
  #' increment the counter and activate/deactivate debug mode when counter goes up to 10
  #' The 'debug' variable keeps track of the debug state on the R side, 'debugFlag' does the same on the JavaScript side
  #' @seealso \code{\link{getNodeInfo}}, \code{\link{updateEvidence}}
  observeEvent(input$clickDebug,{
    if(input$clickDebug == 0) {
      print(debugCounter)
      debugCounter <<- debugCounter+1
      updateNumericInput(session,"clickDebug",value = 1)
    }
    if(debugCounter==10) {
      if(!debug) {
        print("DEBUG MODE ENABLED")
        session$sendCustomMessage("debug", "on")
        showNotification("You entered the developer mode!\nCheck the console to get further details on what is happening under the hood", type = "warning")
        shinyjs::runjs("document.getElementById('disclaimer-content').innerHTML = 'Made by Buonocore T.M. [DEBUG MODE]'")
        show('preTrained')
        shinyjs::show("multiPurposeButton")
      }else{ 
        print("DEBUG MODE DISABLED")
        session$sendCustomMessage("debug", "off")
        shinyjs::runjs("document.getElementById('disclaimer-content').innerHTML = 'Built with Shiny and Javascript'")
        hide('preTrained')
        shinyjs::hide("multiPurposeButton")
      }
      debug <<- !debug
      debugCounter <<- 0
    }
  })
  
  #' When preTrained is clicked:
  #' load and render a pretrained bayesian network
  #' @seealso \code{\link{loadPreTrainedBN}}
  observeEvent(input$preTrained,{
    showLoading()
    bn <<- loadPreTrainedBN()
    updateSelectInput(session,"nodeToQuery",choices = nodes$label)
    output$network <- renderVisNetwork({visNetworkRenderer()})
    updateCollapse(session,id = "collapseLoad", close = "Learn The Network")
    hideLoading()
    shinyjs::runjs("tour.start(true);tour.goTo(6);")
  })
  
  #' When preTrainedFalls is clicked:
  #' load and render a pretrained bayesian network for Falls
  #' @seealso \code{\link{loadPreTrainedBN}}
  observeEvent(input$preTrainedFalls,{
    showLoading()
    bn <<- loadPreTrainedBN("data/bnFallsFull")
    updateSelectInput(session,"nodeToQuery",choices = nodes$label)
    output$network <- renderVisNetwork({visNetworkRenderer()})
    updateCollapse(session,id = "collapseLoad", close = "Learn The Network")
    hideLoading()
    shinyjs::runjs("tour.start(true);tour.goTo(6);")
  })
  
  #' When file2 is uploaded:
  #' read the csv, store the edges info and update the sidebar's query menu
  #' if we already uploaded file1, we can render the network
  #' @seealso \code{\link{renderVisNetwork}} \code{\link{isRenderable}}
  observeEvent(input$edgesFile,{
    temp_edges = edges
    temp_nodes = nodes
    if(!is.null(input$edgesFile)) {
      trySection = try({
        edges<<-read.csv(file = input$edgesFile$datapath,stringsAsFactors=FALSE)
        nodes<<-getNodes(edges)
      })
      if(inherits(trySection, "try-error")) {
        showNotification("Ooops! Something went wrong! Please check the format of your input file.", duration = 15, type = "error")
        edges<<-temp_edges
        nodes<<-temp_nodes
        return(NULL)
      }
      updateSelectInput(session,"nodeToQuery",choices = nodes$label)
      output$network <- renderVisNetwork({visNetworkRenderer()})
      checked$edges <<- TRUE
    }
    else checked$edges <<- FALSE
    if(checked$edges & checked$data) {
      bn<<-createBN(nodes,edges,data)
      updateCollapse(session,id = "collapseLoad", close = "Learn The Network")
      shinyjs::runjs("tour.start(true);tour.goTo(6);")
    }
  })
  
  #' When file3 is uploaded:
  #' read the csv, store the data and learn the bayesian network CPTs
  #' if we already uploaded file1 and file2, we can now query the network
  #' @seealso \code{\link{renderVisNetwork}} \code{\link{isQueriable}}
  observeEvent(input$dataFile,{
    temp_data = data
    if(!is.null(input$dataFile)) {
      trySection = try({
        data<<-read.csv(file = input$dataFile$datapath,stringsAsFactors=TRUE)
        if(ncol(data)<2) stop()
      })
      if(inherits(trySection, "try-error")) {
        showNotification("Ooops! Something went wrong! Please check the format of your input file.", duration = 15, type = "error")
        data<<-temp_data
        return(NULL)
      }
      checked$data<<-TRUE
    }
    if(checked$edges & checked$data) {
      bn<<-createBN(nodes,edges,data)
      isDagLearned = learnDagFromData(nodes,edges,data)
      updateCollapse(session,id = "collapseLoad", close = "Learn The Network")
      if(!isDagLearned) shinyjs::runjs("tour.start(true);tour.goTo(6);")
    }
  })
  
  #' When acrs are checked:
  # observeEvent(input$arcsCheckboxes,{
  #   for(arc in input$arcsCheckboxes){
  #     fromto = strsplit(arc,",")[[1]]
  #     edges<<-rbind(edges,fromto)
  #   }
  #   edges<<-unique(edges)
  # }) 
  
  observeEvent(input$createWithArcs,{
      tempEdges = edges
      for(arc in input$arcsCheckboxes){
        tempEdges = rbind(tempEdges,strsplit(arc,",")[[1]])
      }
      tempEdges=unique(tempEdges)
      bn<<-createBN(nodes,tempEdges,data)
      edges<<-tempEdges
      output$network <- renderVisNetwork({visNetworkRenderer()})
  }) 
  
  
  
  #' When query is uploaded:
  #' retrieve the info 
  #' if we already uploaded file1 and file2, we can now query the network
  #' @seealso \code{\link{renderVisNetwork}} \code{\link{isQueriable}}    
  observeEvent(input$query,{
    evidenceIndices = which(nodes$group=="evidence")  #get the indices of the nodes where the evidence has been set
    evidenceNodes = nodes$label[evidenceIndices]      #get the names of the evidence nodes 
    evidenceStates = nodes$evidence[evidenceIndices]  #get the values of the evidence nodes
    if(!checked$data){
      showNotification("The newtowrk is not fully-defined. Load the data or a pre-trained network first.", type = "warning")
      toggleModal(session, 'queryModal', toggle = 'toggle')
      return(NULL)
    }
    if(length(evidenceIndices)==0){
      showNotification("No evidence set!", type = "warning")
      toggleModal(session, 'queryModal', toggle = 'toggle')
    } else {
      showLoading(query = TRUE)
      #dynamic querying is a bit tricky for cpdist. However, this approach has been suggested by the author of the package himself. 
      queryEvidenceString = paste("(", evidenceNodes, " == '",                         #build a set of node-value couples as a string
                                  sapply(evidenceStates, as.character), "')",
                                  sep = "", collapse = " & ")
      queryNodeString = paste("'", input$nodeToQuery, "'", sep = "")                   #query node as a string
      queryData = eval(parse(text = paste("table(cpdist(bn, ", queryNodeString, ", ",  #merge together and run the query
                                               queryEvidenceString, "))", sep = ""))) 
      #for loop to get more stable results
      for (i in 1:queryRepeat){
        queryData = rbind(queryData,eval(parse(text = paste("table(cpdist(bn, ", queryNodeString, ", ",  #merge together and run the query
                                           queryEvidenceString, "))", sep = ""))))
      }
      output$queryPlot <- renderPlot({queryPlot(data= colMeans(queryData))})
      output$evidenceTable <- renderTable(cbind(Nodes=toupper(evidenceNodes),Evidence=evidenceStates),width = '100%', align = 'c')
    }
  })
  
  
  
  #' When evidence radio buttons change:
  #' update di evidence
  #' @seealso \code{\link{updateEvidence}}
  observeEvent(input$evidence,{
    if(!is.null(input$current_node_id)){
      updateEvidence(input$current_node_id,input$evidence)
    }
  })
  
  output$downloadBN <- downloadHandler(
    filename = "customBN.RData",
    content = function(con) {
      save(bn, file = con)
    }
  )
  
  output$downloadHTML <- downloadHandler(
    filename = "customBN.html",
    content = function(con) {
      visSave(visNetworkRenderer(), file = con)
    }
  )
  
  observeEvent(input$uploadBN,{
    runjs("document.getElementById('bnUpload').click();")
  })
  
  observeEvent(input$help,{
    runjs("window.open('https://github.com/detsutut/shinyDBNet')")
  })
  
  observeEvent(input$bnUpload,{
    if(!is.null(input$bnUpload)) {
      showLoading()
      bn <<- loadPreTrainedBN(input$bnUpload$datapath)
      updateSelectInput(session,"nodeToQuery",choices = nodes$label)
      output$network <- renderVisNetwork({visNetworkRenderer()})
      updateCollapse(session,id = "collapseLoad", close = "Learn The Network")
      hideLoading()
    }
  })
  
  ##### 2.5 ) Functions #####
  
  #' Generate a Bayesian Network from the inputs.
  #' CPTs are learnt from the data. DAG is built combining nodes and edges info.
  #' 
  #' @param nodes the information about the nodes of the network
  #' @param edges the information about the edges of the network
  #' @param data the actual dataset from where to get the CPTs
  #' @return a bayesian network object, DAG included
  #' @examples
  #' nodes = read.csv("nodes.csv")
  #' edges = read.csv("edges.csv")
  #' data = read.csv("dataset.csv")
  #' bn = createBN(nodes,edges,data)
  createBN = function(nodes,edges,data){
    bn = try({
          cat("creating bn...")
          showLoading()
          dag= dagtools.new(nodelist = nodes$label) %>%
               dagtools.fill(arcs_matrix = edges)
          b = bntools.fit(dag = dag,data = data)
          attr(b,"dag") = dag
          b
        })
    hideLoading()
    if(inherits(bn, "try-error")) {
      showNotification("Ooops! Something went wrong! Please check the format of your input files and the consistency of your variables names. Remember also that closed loops are not allowed in Bayesian Networks!", duration = 15, type = "error")
      return(NULL)
    } else {
      cat("done!\n")
      return(bn)
    }
  }
  
  #' Force rendered network refresh
  refreshNet = function(){
    visUpdateNodes(graph = visNetworkProxy('network', session = session), nodes = nodes)
  }
  
  #' Update the nodes table with new info and refreshes the net
  #' 
  #' @param id the id of the node to update
  #' @param evidence the value to set as evidence
  #' @examples
  #' updateEvidence(1,"male")
  #' @seealso \code{\link{setNodeInfo}}
  updateEvidence = function(id,evidence){
    setNodeInfo(id, evidence = evidence)
    if(evidence == "no_evidence"){
      setNodeInfo(id, evidenceYN = FALSE)
      output$nodePlot <- renderPlot({nodePlot(FALSE)})
    } else {
      setNodeInfo(id, evidenceYN = TRUE)
      output$nodePlot <- renderPlot({nodePlot(TRUE)})
    }
    refreshNet()
  }
  
  #' Update the radio buttons with the possible values of the target node
  #' 
  #' @param id the id of the target node
  updateRadios = function(id){
    nodeInfo = getNodeInfo(id)
    updateRadioButtons(session, "evidence",choices = nodeInfo$choices, selected = nodeInfo$evidence)
  }
  
  #' Hide the loading splashscreen
  #' 
  #' @param modal the splashscreen to hide is on a modal
  #' @param query the splashscreen to hide is on a query panel
  hideLoading = function(modal=FALSE, query = FALSE){
    if(modal) hideElement(id = 'loading2')
    else if(query) hideElement(id = 'loading3')
    else hideElement(id = 'loading')
  }
  
  #' Show the loading splashscreen
  #' 
  #' @param modal show the loading splashscreen on a modal
  #' @param query show the loading splashscreen on the query panel
  showLoading = function(modal=FALSE, query = FALSE){
    if(modal) showElement(id = 'loading2')
    else if(query) showElement(id = 'loading3')
    else showElement(id = 'loading')
  }
  
  #' Retrieve all the info the network has about the target node
  #' 
  #' @param targetNode the id of the target node
  #' @param verbose print the info
  #' @param byName targetNode is the name of the node instead of the id
  #' @return a list of properties of the target node
  #' @examples
  #' myNodeInfo = getNodeInfo(targetNode = "gender",byName = TRUE)
  getNodeInfo = function(targetNode, verbose = FALSE, byName = FALSE){
    if(byName){
      name = targetNode
      targetNode = nodes[which(nodes$label==targetNode),]$id
    }
    if(verbose) print(nodes[targetNode,])
    name = nodes[targetNode,]$label
    probs = bn[[as.character(name)]]$prob
    choices = c("no_evidence",rownames(probs))
    evidenceYN = (!is.na(nodes[targetNode,]$group) && nodes[targetNode,]$group == "evidence")
    evidence = nodes[targetNode,]$evidence
    return(list('name'=name, 'id' = targetNode, 'probs'=probs, 'choices'=choices, 'evidenceYN'=evidenceYN, 'evidence'=evidence))
  }
  
  #' Update target node's info.
  #' 
  #' @param targetNode the id of the target node
  #' @param name the name of the node. If NULL, not updated
  #' @param probs the probabilities of the node. If NULL, not updated
  #' @param evidenceYN the evidence flag of the node. TRUE/FALSE. If NULL, not updated
  #' @param evidence the selected value of the node. If NULL, not updated
  #' @examples
  #' setNodeInfo(1,name="gender", evidenceYN = TRUE, evidence = "male")
  setNodeInfo = function(targetNode, name=NULL, probs = NULL, evidenceYN=NULL, evidence=NULL){
    if(!is.null(name)) {
      nodes[targetNode,]$label <<- name
      if(!is.null(probs)) bn[[as.character(name)]]$prob <<- probs
    } else if(!is.null(probs)) bn[[as.character(nodes[targetNode,]$label)]]$prob <<- probs
    if(!is.null(evidenceYN)) {
      if(evidenceYN) nodes[targetNode,]$group <<- "evidence"
      else nodes[targetNode,]$group <<- "NA"
    }
    if(!is.null(evidence)) nodes[targetNode,]$evidence <<- evidence
  }
  
  #' Load a pretrained Bayesian Network, stored on the server.
  #' @return the bayesian network object
  loadPreTrainedBN = function(file = "data/bn_car_insurance"){
    bn_temp = bn
    nodes_temp = nodes
    edges_temp = edges
    trySection = try({
      load(file)
      bn<<-bn
      dag = attr(bn,"dag")
      edges<<- as.data.frame(dag$arcs)
      nodes<<-getNodes(edges)
    })
    if(inherits(trySection, "try-error")) {
      showNotification("The network can\'t be loaded. Please check the input again.", duration = 15, type = "error")
      nodes<<-nodes_temp
      edges<<-edges_temp
      bn<<-bn_temp
      return(bn)
    } else {
      checked$data <<- TRUE
      return(bn)
    }
  }
  
  #learnDagFromData
  #Work In progress
  learnDagFromData = function(nodes,edges,data){
    bootstrappedNets = boot.strength(data, R = 5, algorithm = "tabu",algorithm.args = list(whitelist = edges))
    dag_learned = averaged.network(bootstrappedNets, threshold = 0.19)
    edges_learned = as.data.frame(dag_learned$arcs,stringsAsFactors = FALSE)
    diff = dplyr::setdiff(edges_learned,edges)
    if(nrow(diff)>0){
      choiceNames = c()
      choiceValues = list()
      for(i in 1:nrow(diff)){
        ind_match = which(bootstrappedNets$from == diff[i,1] & bootstrappedNets$to == diff[i,2])
        strength = bootstrappedNets$strength[ind_match]
        choiceNames = c(choiceNames,paste0(toupper(as.character(diff[i,1]))," --> ",toupper(as.character(diff[i,2])), " [",strength*100,"%]"))
        choiceValues[[i]] =paste(diff[i,1],diff[i,2],sep = ",")
      }
      updateCheckboxGroupInput(session,"arcsCheckboxes", choiceNames = choiceNames, choiceValues = choiceValues)
      toggleModal(session, 'arcsMenu', toggle = 'toggle')
      return(TRUE)
    } else {return(FALSE)}
  }
  
}