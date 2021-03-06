

boot_emIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){
  UseMethod("boot_emIRT")
}

boot_emIRT.emIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){
  # Fallback method if no specific bootstrapping function is available
  stop(paste0("Bootstrapping for models of class \"", class(emIRT.out)[1], "\" is not available (yet)."))
}

### BEGIN BINARY IRT
boot_emIRT.binIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){

  if(class(emIRT.out)[1] == "binIRT"){

    ## Extract parameters to calculate vote probabilities
    rc <- .data$votes
    rollc <- .data
    probmat <- matrix(NA, nrow=nrow(rc), ncol=ncol(rc))
    idealpts <- emIRT.out$means$x
    beta.binIRT <- emIRT.out$means$beta


    ## Calculate vote probabilities for observed votes
    for(i in 1:nrow(probmat)){
      for(j in 1:ncol(probmat)){
        if(rc[i,j] %in% c(-1,1) ) probmat[i,j] = pnorm( beta.binIRT[j,1] + beta.binIRT[j,2]*idealpts[i] )
      }
    }

    pseudo.rc <- vector("list", Ntrials)
    binIRT.trials <- matrix(NA, nrow=length(idealpts), ncol=Ntrials)

    for(trial in 1:Ntrials){

      ## Generate a bootstrapped roll call matrix
      probs <- runif(nrow(probmat)*ncol(probmat))
      pseudo.rc[[trial]] <- 1*(probmat > probs)

      pseudo.rc[[trial]][ pseudo.rc[[trial]]==0 ] <- -1
      pseudo.rc[[trial]][ is.na(pseudo.rc[[trial]]) ] <- 0
      rownames(pseudo.rc[[trial]]) <- rownames(rc)
      colnames(pseudo.rc[[trial]]) <- colnames(rc)

      rollc$votes <- pseudo.rc[[trial]]
      sink("emIRTjunk.kjz")
      binIRT.trials[,trial] <- binIRT(rollc, .starts = .starts, .priors = .priors, .control = .control)$means$x
      sink()
      unlink("emIRTjunk.kjz")

      if(trial %% verbose == 0){
        cat("\n\t Iteration", trial, "complete...")
        flush.console()
      }

    }

    emIRT.out$bse$x <- apply(binIRT.trials,1,sd)
    return(emIRT.out)

  }   #end binIRT()
}
### END BINARY IRT

### BEGIN DYNAMIC IRT
boot_emIRT.dynIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){
  if(class(emIRT.out)[1] == "dynIRT"){

    ## Extract parameters to calculate vote probabilities
    rc <- .data$rc
    vote_year <- .data$bill.session + 1
    probmat <- matrix(NA, nrow=nrow(.data$rc), ncol=ncol(.data$rc))
    idealpts <- emIRT.out$means$x
    alpha.dynIRT <- emIRT.out$means$alpha
    beta.dynIRT <- emIRT.out$means$beta

    ## Calculate vote probabilities for observed votes
    for(i in 1:nrow(probmat)){
      for(j in 1:ncol(probmat)){
        if(rc[i,j] != 0) probmat[i,j] = pnorm(alpha.dynIRT[j] + beta.dynIRT[j]*idealpts[i,vote_year[j]])
      }
    }

    pseudo.rc <- vector("list", Ntrials)
    dynIRT.result <- vector("list", Ntrials)

    for(trial in 1:Ntrials){

      ## Generate a bootstrapped roll call matrix
      pseudo.rc[[trial]] <- 1*(probmat > runif(nrow(probmat)*ncol(probmat)))
      pseudo.rc[[trial]][pseudo.rc[[trial]] == 0] <- -1
      pseudo.rc[[trial]] [is.na(pseudo.rc[[trial]])] <- 0
      rownames(pseudo.rc[[trial]]) <- rownames(rc)
      colnames(pseudo.rc[[trial]]) <- colnames(rc)
      pseudo.data <- .data
      pseudo.data$rc <- pseudo.rc[[trial]]

      sink("emIRTjunk.kjz")
      dynIRT.result[[trial]] <- dynIRT(pseudo.data, .starts = .starts, .priors = .priors, .control = .control)$means$x
      sink()
      unlink("emIRTjunk.kjz")

      if(trial %% verbose == 0){
        cat("\n\t Iteration", trial, "complete...")
        flush.console()
      }

    }

    getindex <- function(x, row, col){ return(x[row,col])}
    bse.idealpts <- matrix(NA, nrow=nrow(idealpts), ncol=ncol(idealpts))
    for(i in 1:nrow(bse.idealpts)){
      for(j in (.data$startlegis[i] + 1):(.data$endlegis[i] + 1) ){
        bse.idealpts[i,j] <- sd(sapply(dynIRT.result, getindex, i, j))
      }
    }

    emIRT.out$bse$x <- bse.idealpts
    return(emIRT.out)

  }  #end dynIRT()
}
### END DYNAMIC IRT

boot_emIRT.hierIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){

  ### BEGIN HIERIRT()
  if(class(emIRT.out)[1] == "hierIRT"){

    ## Extract parameters to calculate vote probabilities
    y <- .data$y
    z <- .data$z
    g <- .data$g + 1
    i <- .data$i + 1
    j <- .data$j + 1
    ND <- .data$ND
    NG <- .data$NG
    NJ <- .data$NJ
    NI <- .data$NI
    NL <- .data$NL
    pseudodata <- .data
    probmat <- matrix(NA, nrow=nrow(y), ncol=1)

    x.hierIRT <- emIRT.out$means$x_implied
    alpha.hierIRT <- emIRT.out$means$alpha
    beta.hierIRT <- emIRT.out$means$beta


    ## Calculate vote probabilities for observed votes
    ## if(y[l,1] %in% c(-1,1)) not needed because only observed votes recorded
    for(l in 1:nrow(probmat)){
      probmat[l,1] = pnorm( alpha.hierIRT[j[l]] + beta.hierIRT[j[l]]*x.hierIRT[i[l]] )
    }

    pseudo.y <- vector("list", Ntrials)
    hierIRT.trials <- matrix(NA, nrow=length(x.hierIRT), ncol=Ntrials)

    for(trial in 1:Ntrials){

      ## Generate a bootstrapped roll call matrix
      probs <- runif(nrow(probmat))
      pseudo.y[[trial]] <- 1*(probmat > probs)

      pseudo.y[[trial]][ pseudo.y[[trial]]==0 ] <- -1
      table(pseudo.y[[trial]])
      table(y)

      pseudodata$y <- pseudo.y[[trial]]

      sink("emIRTjunk.kjz")
      hierIRT.trials[,trial] <- hierIRT(pseudodata, .starts = .starts, .priors = .priors, .control = .control)$means$x_implied
      sink()
      unlink("emIRTjunk.kjz")

      if(trial %% verbose == 0){
        cat("\n\t Iteration", trial, "complete...")
        flush.console()
      }

    }

    emIRT.out$bse$x_implied <- apply(hierIRT.trials,1,sd)
    return(emIRT.out)

  } #end hierIRT()
}
### END HIERIRT()


### BEGIN ORDINAL IRT
boot_emIRT.ordIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){
  if(class(emIRT.out)[1] == "ordIRT"){

    ## Extract parameters to calculate vote probabilities
    rc <- .data
    probmat1 <- matrix(NA, nrow=nrow(rc), ncol=ncol(rc))
    probmat2 <- matrix(NA, nrow=nrow(rc), ncol=ncol(rc))
    idealpts <- emIRT.out$means$x
    beta.ordIRT <- emIRT.out$means$beta
    alpha.ordIRT <- emIRT.out$means$tau
    tau.ordIRT <- emIRT.out$means$Delta

    ## Calculate vote probabilities for observed votes
    for(i in 1:nrow(probmat1)){
      for(j in 1:ncol(probmat1)){
        if(rc[i,j] != 0){
          probmat1[i,j] = pnorm( -tau.ordIRT[j]*alpha.ordIRT[j] - beta.ordIRT[j]*tau.ordIRT[j]*idealpts[i] )
          probmat2[i,j] = pnorm( -tau.ordIRT[j]*alpha.ordIRT[j] + tau.ordIRT[j] - beta.ordIRT[j]*tau.ordIRT[j]*idealpts[i] )
        }
      }
    }

    pseudo.rc <- vector("list", Ntrials)
    ordIRT.trials <- matrix(NA, nrow=length(idealpts), ncol=Ntrials)

    for(trial in 1:Ntrials){

      ## Generate a bootstrapped roll call matrix
      probs <- runif(nrow(probmat1)*ncol(probmat1))
      pseudo.rc[[trial]] <- 3*(probs > probmat2) + 2*(probs > probmat1 & probs < probmat2) + 1*(probs < probmat1)
      rownames(pseudo.rc[[trial]]) <- rownames(rc)
      colnames(pseudo.rc[[trial]]) <- colnames(rc)


      sink("emIRTjunk.kjz")
      ordIRT.trials[,trial] <- ordIRT(pseudo.rc[[trial]], .starts = .starts, .priors = .priors, .control = .control)$means$x
      sink()
      unlink("emIRTjunk.kjz")

      if(trial %% verbose == 0){
        cat("\n\t Iteration", trial, "complete...")
        flush.console()
      }

    }

    emIRT.out$bse$x <- apply(ordIRT.trials,1,sd)
    return(emIRT.out)

  }  # end ordIRT()
}
### END ORDINAL IRT

boot_emIRT.networkIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){
  rc <- .data
  n_rows <- nrow(.data)
  n_cols <- ncol(.data)

  # Matrices -> vector (the code estimates only one-dimensional models)
  alpha <- emIRT.out$means$alpha[, 1]
  beta <- emIRT.out$means$beta[, 1]
  w <- emIRT.out$means$w[, 1]
  theta <- emIRT.out$means$theta[, 1]

  probmat <- pnorm(
    matrix(beta, n_rows, n_cols, byrow = FALSE) +
      matrix(alpha, n_rows, n_cols, byrow = TRUE) +
      matrix(theta, n_rows, n_cols, byrow = FALSE)^2 +
      matrix(w, n_rows, n_cols, byrow = TRUE)^2
  )

  pseudo.rc <- vector("list", Ntrials)
  networkIRT.trials.alpha <- matrix(NA_real_, nrow=length(alpha), ncol=Ntrials)
  networkIRT.trials.beta <- matrix(NA_real_, nrow=length(beta), ncol=Ntrials)
  networkIRT.trials.w <- matrix(NA_real_, nrow=length(w), ncol=Ntrials)
  networkIRT.trials.theta <- matrix(NA_real_, nrow=length(theta), ncol=Ntrials)

  for(trial in 1:Ntrials){

    ## Generate a bootstrapped roll call matrix
    probs <- matrix(runif(n_rows * n_cols), nrow = n_rows, ncol = n_cols)
    pseudo.rc[[trial]] <- 1 * ((1 * (rand <= probmat)) == rc)
    rownames(pseudo.rc[[trial]]) <- rownames(rc)
    colnames(pseudo.rc[[trial]]) <- colnames(rc)


    sink("emIRTjunk.kjz")
    est <- suppressMessages(
      networkIRT(pseudo.rc[[trial]], .starts = .starts, .priors = .priors, .control = .control)
    )
    sink()
    unlink("emIRTjunk.kjz")

    # Do not store results if algorithm did not converge or converged
    # after too little iterations (actually an error but no signalled)
    if ((!est$runtime$conv) | (est$runtime$iters < 10)) {
      next
    }

    networkIRT.trials.alpha[, trial] <- est$means$alpha[, 1]
    networkIRT.trials.beta[, trial] <- est$means$beta[, 1]
    networkIRT.trials.w[, trial] <- est$means$w[, 1]
    networkIRT.trials.theta[, trial] <- est$means$theta[, 1]

    if(trial %% verbose == 0){
      cat("\n\t Iteration", trial, "complete...")
      flush.console()
    }

  }

  # Check an warn for non-converged trials
  if (anyNA(networkIRT.trials.alpha)) {
    warning(
      paste0(
        sum(is.na(networkIRT.trials.alpha[1, ])),
        " run(s) did not converge. Effective sample size is ",
        sum(!is.na(networkIRT.trials.alpha[1, ])),
        "."
      ),
      call. = FALSE
    )
  }

  emIRT.out$bse$alpha[, trial] <- apply(networkIRT.trials.alpha, 1, sd, na.rm = TRUE)
  emIRT.out$bse$beta[, trial] <- apply(networkIRT.trials.beta, 1, sd, na.rm = TRUE)
  emIRT.out$bse$w[, trial] <- apply(networkIRT.trials.w, 1, sd, na.rm = TRUE)
  emIRT.out$bse$theta[, trial] <- apply(networkIRT.trials.theta, 1, sd, na.rm = TRUE)

  return(emIRT.out)
}

boot_emIRT.poisIRT <- function(emIRT.out, .data, .starts, .priors, .control, Ntrials=50, verbose=10){
  NextMethod("boot_emIRT")
}
