import { HttpClient } from '@angular/common/http';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';

enum QueryType { Terceros = 0, Pedidos = 1 }
enum EcommerceType { Shopify = 0, VTEX = 1 }
enum AppVersion { V1 = 0, V2 = 1 }

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

interface PaymentMapping {
  gatewayName: string;
  erpCode: string;
}

interface QueryConfiguration {
  clientName: string;
  queryType: QueryType;
  ecommerce: EcommerceType;
  version: AppVersion;
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
  idTipoDocto: string;
  idCo: string;
  idVendedor: string;
  unidadMedidaItem: string;
  referenciaFlete: string;
  payments: PaymentMapping[];
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FormsModule, CommonModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class AppComponent implements OnInit {
  QueryType = QueryType;
  EcommerceType = EcommerceType;
  AppVersion = AppVersion;

  config: QueryConfiguration = {
    clientName: 'NuevoCliente',
    queryType: QueryType.Terceros,
    ecommerce: EcommerceType.Shopify,
    version: AppVersion.V1,
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
    dynamicEntities: [],
    idTipoDocto: 'EPV',
    idCo: '001',
    idVendedor: '9999',
    unidadMedidaItem: 'UND',
    referenciaFlete: 'FLETES',
    payments: []
  };

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.addTax();
    this.addPayment();
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

  addPayment() {
    this.config.payments.push({ gatewayName: '', erpCode: '' });
  }

  removePayment(index: number) {
    this.config.payments.splice(index, 1);
  }

  onQueryTypeChange() {
    if (this.config.queryType === QueryType.Terceros) {
      this.config.descripcionConector = 'Ecommerce_Terceros_Clientes';
    } else {
      this.config.descripcionConector = 'Ecommerce_Pedidos';
    }
  }

  generateSql() {
    this.http.post('http://localhost:5000/api/generator/generate', this.config, { responseType: 'blob' })
      .subscribe(blob => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        const suffix = this.config.queryType === QueryType.Terceros ? 'Terceros' : 'Pedidos';
        a.download = `${this.config.clientName}_${suffix}.sql`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      });
  }
}
