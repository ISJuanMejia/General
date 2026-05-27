import { HttpClient } from '@angular/common/http';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';

interface TaxConfig {
  tipoReg: string;
  clase: string;
  valorTercero: string;
}

interface DynamicEntityConfig {
  grupoEntidad: string;
  idEntidad: string;
  idAtributo: string;
  idMaestro: string;
  idMaestroDetalle: string;
}

interface QueryConfiguration {
  clientName: string;
  idDocumento: number;
  descripcionConector: string;
  indicaParalelismo: boolean;
  idSucursal: string;
  idListaPrecio: string;
  clientOriginData: number;
  locationOriginData: number;
  idPaisDefecto: string;
  idDptoDefecto: string;
  idCiudadDefecto: string;
  idTipoIdentDefecto: string;
  indTipoTerceroDefecto: string;
  processClientWithoutId: boolean;
  idCiiu: string;
  taxes: TaxConfig[];
  dynamicEntities: DynamicEntityConfig[];
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FormsModule, CommonModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class AppComponent implements OnInit {
  config: QueryConfiguration = {
    clientName: 'NuevoCliente',
    idDocumento: 200000,
    descripcionConector: 'Ecommerce_Terceros_Clientes',
    indicaParalelismo: true,
    idSucursal: '001',
    idListaPrecio: '001',
    clientOriginData: 4,
    locationOriginData: 1,
    idPaisDefecto: '169',
    idDptoDefecto: '05',
    idCiudadDefecto: '001',
    idTipoIdentDefecto: 'C',
    indTipoTerceroDefecto: '1',
    processClientWithoutId: false,
    idCiiu: '0081',
    taxes: [],
    dynamicEntities: []
  };

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.addTax();
  }

  addTax() {
    this.config.taxes.push({ tipoReg: '46', clase: '1', valorTercero: '1' });
  }

  removeTax(index: number) {
    this.config.taxes.splice(index, 1);
  }

  addEntity() {
    this.config.dynamicEntities.push({
      grupoEntidad: 'FE TERCERO',
      idEntidad: '',
      idAtributo: '',
      idMaestro: '',
      idMaestroDetalle: ''
    });
  }

  removeEntity(index: number) {
    this.config.dynamicEntities.splice(index, 1);
  }

  generateSql() {
    this.http.post('http://localhost:5000/api/generator/generate', this.config, { responseType: 'blob' })
      .subscribe(blob => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${this.config.clientName}_Terceros.sql`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      });
  }
}
