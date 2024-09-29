<!DOCTYPE html>
<html lang="en">

<head>
  <meta name="robots" content="noindex">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>THIN - WHOIS Checker</title>
  <link rel="stylesheet" href="style.css">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH" crossorigin="anonymous">
</head>

<body class="bg-dark text-light">
  <div class="mx-auto text-center mt-5">
    <h1 class="display-2 my-4">WHOIS Checker</h1>
    <form method="POST" class="container" id="takeDomainForm">
      <input type="text" class="" id="domena" name="domena">
      <input type="submit" value="Hledat" class="button">
      <br>
      <p class="my-4">Stačí zadat doménu, například: cesky-hosting.cz</p>
    </form>
    <div id="loading" class="my-2" style="display: none;">
    </div>
    <div class="my-5 alert mx-auto" id="result" style="display:none;width:25%;"></div>
    <div class="my-5" id="data"></div>
  </div>
  <script src="gifs.js"></script>
  <script>
function showLoading() {
    const loadingElement = document.getElementById("loading");
    const randomCislo = Math.floor(Math.random() * gifs.length);
    const vybranyGif = gifs[randomCislo];
    loadingElement.innerHTML = `<h3><strong>Čekám na WHOIS ...</strong></h3><br><img src="${vybranyGif}" alt="Čekám na WHOIS ..." width="256" height="256" frameBorder="0">`
    loadingElement.style.display = "block"; // Show loading element
}

function hideLoading() {
    document.getElementById("loading").style.display = "none"; // Hide loading element
}
function executeScript(domain) {
    showLoading();
    const xhr = new XMLHttpRequest();
    xhr.open("POST", "run.php", true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onreadystatechange = function() {
        if (this.readyState === XMLHttpRequest.DONE) {
            hideLoading();
            if (this.status === 200) {
                try {
                    console.log("Raw: ", this.responseText)
                    const response = JSON.parse(this.responseText);
                    loadData(response.log); // assuming response.log is the correct path
                } catch (error) {
                    console.error("Failed to parse JSON:", error);
                }
            } else {
                console.error("Neco se pokazilo:", this.status);
            }
        }
    };
    xhr.send('domena=' + encodeURIComponent(domain));
}

    function loadData(log) {
      const xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
          document.getElementById("data").innerHTML = this.responseText;
        }
      };

      xhttp.open("GET", log, true);
      xhttp.setRequestHeader('Content-Type', 'text/plain');
      xhttp.send();
    }
    document.getElementById("takeDomainForm").addEventListener("submit", function(event) {
      event.preventDefault();
      const input = document.getElementById("domena").value;
      const status = document.getElementById("result");
      if (input == "") {
        status.style.display = "block";
        status.classList.remove("alert-danger");
        status.classList.add("alert-warning");
        status.innerHTML = "Je potřeba vyplnit doménu";
      } else if (!/^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$/.test(input)) {
        status.style.display = "block";
        status.classList.add("alert-danger");
        status.innerHTML = "Neplatný formát domény, použij <q>domena.cz</q>";
      } else {
        status.classList.remove("alert-warning", "alert-danger");
        status.classList.add("alert-success");
        const xhr = new XMLHttpRequest();
        xhr.open('POST', 'takeDomain.php', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
          if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
              document.getElementById("result").innerHTML = xhr.responseText;
            } else {
              document.getElementById("result").innerHTML = "Něco se pokazilo";
            }
          }
        };
        xhr.send('domena=' + encodeURIComponent(input));
        const reset = () => {
          document.getElementById("domena").value = "";
        }
	executeScript(input);
        reset();
      };
    });
  </script>
</body>
</html>
