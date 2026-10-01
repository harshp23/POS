// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OrdersTable extends Orders with TableInfo<$OrdersTable, OrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientOrderIdMeta =
      const VerificationMeta('clientOrderId');
  @override
  late final GeneratedColumn<String> clientOrderId = GeneratedColumn<String>(
      'client_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyCodeMeta =
      const VerificationMeta('currencyCode');
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
      'currency_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderTypeMeta =
      const VerificationMeta('orderType');
  @override
  late final GeneratedColumn<String> orderType = GeneratedColumn<String>(
      'order_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tableLabelMeta =
      const VerificationMeta('tableLabel');
  @override
  late final GeneratedColumn<String> tableLabel = GeneratedColumn<String>(
      'table_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _opsStatusMeta =
      const VerificationMeta('opsStatus');
  @override
  late final GeneratedColumn<String> opsStatus = GeneratedColumn<String>(
      'ops_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('open'));
  static const VerificationMeta _channelMeta =
      const VerificationMeta('channel');
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
      'channel', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('POS'));
  static const VerificationMeta _guestsMeta = const VerificationMeta('guests');
  @override
  late final GeneratedColumn<int> guests = GeneratedColumn<int>(
      'guests', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _serverNameMeta =
      const VerificationMeta('serverName');
  @override
  late final GeneratedColumn<String> serverName = GeneratedColumn<String>(
      'server_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _discountPctMeta =
      const VerificationMeta('discountPct');
  @override
  late final GeneratedColumn<double> discountPct = GeneratedColumn<double>(
      'discount_pct', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _taxPctMeta = const VerificationMeta('taxPct');
  @override
  late final GeneratedColumn<double> taxPct = GeneratedColumn<double>(
      'tax_pct', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _billNoMeta = const VerificationMeta('billNo');
  @override
  late final GeneratedColumn<int> billNo = GeneratedColumn<int>(
      'bill_no', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _settledAtMeta =
      const VerificationMeta('settledAt');
  @override
  late final GeneratedColumn<DateTime> settledAt = GeneratedColumn<DateTime>(
      'settled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _displayNoMeta =
      const VerificationMeta('displayNo');
  @override
  late final GeneratedColumn<String> displayNo = GeneratedColumn<String>(
      'display_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        clientOrderId,
        locationId,
        currencyCode,
        status,
        orderType,
        tableLabel,
        createdAt,
        opsStatus,
        channel,
        source,
        guests,
        serverName,
        notes,
        discountPct,
        taxPct,
        billNo,
        paymentMethod,
        settledAt,
        customerName,
        displayNo
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(Insertable<OrderRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_order_id')) {
      context.handle(
          _clientOrderIdMeta,
          clientOrderId.isAcceptableOrUnknown(
              data['client_order_id']!, _clientOrderIdMeta));
    } else if (isInserting) {
      context.missing(_clientOrderIdMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
          _currencyCodeMeta,
          currencyCode.isAcceptableOrUnknown(
              data['currency_code']!, _currencyCodeMeta));
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('order_type')) {
      context.handle(_orderTypeMeta,
          orderType.isAcceptableOrUnknown(data['order_type']!, _orderTypeMeta));
    } else if (isInserting) {
      context.missing(_orderTypeMeta);
    }
    if (data.containsKey('table_label')) {
      context.handle(
          _tableLabelMeta,
          tableLabel.isAcceptableOrUnknown(
              data['table_label']!, _tableLabelMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('ops_status')) {
      context.handle(_opsStatusMeta,
          opsStatus.isAcceptableOrUnknown(data['ops_status']!, _opsStatusMeta));
    }
    if (data.containsKey('channel')) {
      context.handle(_channelMeta,
          channel.isAcceptableOrUnknown(data['channel']!, _channelMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('guests')) {
      context.handle(_guestsMeta,
          guests.isAcceptableOrUnknown(data['guests']!, _guestsMeta));
    }
    if (data.containsKey('server_name')) {
      context.handle(
          _serverNameMeta,
          serverName.isAcceptableOrUnknown(
              data['server_name']!, _serverNameMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('discount_pct')) {
      context.handle(
          _discountPctMeta,
          discountPct.isAcceptableOrUnknown(
              data['discount_pct']!, _discountPctMeta));
    }
    if (data.containsKey('tax_pct')) {
      context.handle(_taxPctMeta,
          taxPct.isAcceptableOrUnknown(data['tax_pct']!, _taxPctMeta));
    }
    if (data.containsKey('bill_no')) {
      context.handle(_billNoMeta,
          billNo.isAcceptableOrUnknown(data['bill_no']!, _billNoMeta));
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    }
    if (data.containsKey('settled_at')) {
      context.handle(_settledAtMeta,
          settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    }
    if (data.containsKey('display_no')) {
      context.handle(_displayNoMeta,
          displayNo.isAcceptableOrUnknown(data['display_no']!, _displayNoMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientOrderId};
  @override
  OrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderRow(
      clientOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_order_id'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id'])!,
      currencyCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency_code'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      orderType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_type'])!,
      tableLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_label']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      opsStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ops_status'])!,
      channel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      guests: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}guests']),
      serverName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_name'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      discountPct: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}discount_pct'])!,
      taxPct: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}tax_pct'])!,
      billNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bill_no']),
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_method']),
      settledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}settled_at']),
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!,
      displayNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_no']),
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }
}

class OrderRow extends DataClass implements Insertable<OrderRow> {
  final String clientOrderId;
  final String locationId;
  final String currencyCode;
  final String status;
  final String orderType;
  final String? tableLabel;
  final DateTime createdAt;
  final String opsStatus;
  final String channel;
  final String source;
  final int? guests;
  final String serverName;
  final String notes;
  final double discountPct;
  final double taxPct;
  final int? billNo;
  final String? paymentMethod;
  final DateTime? settledAt;
  final String customerName;
  final String? displayNo;
  const OrderRow(
      {required this.clientOrderId,
      required this.locationId,
      required this.currencyCode,
      required this.status,
      required this.orderType,
      this.tableLabel,
      required this.createdAt,
      required this.opsStatus,
      required this.channel,
      required this.source,
      this.guests,
      required this.serverName,
      required this.notes,
      required this.discountPct,
      required this.taxPct,
      this.billNo,
      this.paymentMethod,
      this.settledAt,
      required this.customerName,
      this.displayNo});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_order_id'] = Variable<String>(clientOrderId);
    map['location_id'] = Variable<String>(locationId);
    map['currency_code'] = Variable<String>(currencyCode);
    map['status'] = Variable<String>(status);
    map['order_type'] = Variable<String>(orderType);
    if (!nullToAbsent || tableLabel != null) {
      map['table_label'] = Variable<String>(tableLabel);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['ops_status'] = Variable<String>(opsStatus);
    map['channel'] = Variable<String>(channel);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || guests != null) {
      map['guests'] = Variable<int>(guests);
    }
    map['server_name'] = Variable<String>(serverName);
    map['notes'] = Variable<String>(notes);
    map['discount_pct'] = Variable<double>(discountPct);
    map['tax_pct'] = Variable<double>(taxPct);
    if (!nullToAbsent || billNo != null) {
      map['bill_no'] = Variable<int>(billNo);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    if (!nullToAbsent || settledAt != null) {
      map['settled_at'] = Variable<DateTime>(settledAt);
    }
    map['customer_name'] = Variable<String>(customerName);
    if (!nullToAbsent || displayNo != null) {
      map['display_no'] = Variable<String>(displayNo);
    }
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      clientOrderId: Value(clientOrderId),
      locationId: Value(locationId),
      currencyCode: Value(currencyCode),
      status: Value(status),
      orderType: Value(orderType),
      tableLabel: tableLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(tableLabel),
      createdAt: Value(createdAt),
      opsStatus: Value(opsStatus),
      channel: Value(channel),
      source: Value(source),
      guests:
          guests == null && nullToAbsent ? const Value.absent() : Value(guests),
      serverName: Value(serverName),
      notes: Value(notes),
      discountPct: Value(discountPct),
      taxPct: Value(taxPct),
      billNo:
          billNo == null && nullToAbsent ? const Value.absent() : Value(billNo),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      settledAt: settledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(settledAt),
      customerName: Value(customerName),
      displayNo: displayNo == null && nullToAbsent
          ? const Value.absent()
          : Value(displayNo),
    );
  }

  factory OrderRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderRow(
      clientOrderId: serializer.fromJson<String>(json['clientOrderId']),
      locationId: serializer.fromJson<String>(json['locationId']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      status: serializer.fromJson<String>(json['status']),
      orderType: serializer.fromJson<String>(json['orderType']),
      tableLabel: serializer.fromJson<String?>(json['tableLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      opsStatus: serializer.fromJson<String>(json['opsStatus']),
      channel: serializer.fromJson<String>(json['channel']),
      source: serializer.fromJson<String>(json['source']),
      guests: serializer.fromJson<int?>(json['guests']),
      serverName: serializer.fromJson<String>(json['serverName']),
      notes: serializer.fromJson<String>(json['notes']),
      discountPct: serializer.fromJson<double>(json['discountPct']),
      taxPct: serializer.fromJson<double>(json['taxPct']),
      billNo: serializer.fromJson<int?>(json['billNo']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      settledAt: serializer.fromJson<DateTime?>(json['settledAt']),
      customerName: serializer.fromJson<String>(json['customerName']),
      displayNo: serializer.fromJson<String?>(json['displayNo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientOrderId': serializer.toJson<String>(clientOrderId),
      'locationId': serializer.toJson<String>(locationId),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'status': serializer.toJson<String>(status),
      'orderType': serializer.toJson<String>(orderType),
      'tableLabel': serializer.toJson<String?>(tableLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'opsStatus': serializer.toJson<String>(opsStatus),
      'channel': serializer.toJson<String>(channel),
      'source': serializer.toJson<String>(source),
      'guests': serializer.toJson<int?>(guests),
      'serverName': serializer.toJson<String>(serverName),
      'notes': serializer.toJson<String>(notes),
      'discountPct': serializer.toJson<double>(discountPct),
      'taxPct': serializer.toJson<double>(taxPct),
      'billNo': serializer.toJson<int?>(billNo),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'settledAt': serializer.toJson<DateTime?>(settledAt),
      'customerName': serializer.toJson<String>(customerName),
      'displayNo': serializer.toJson<String?>(displayNo),
    };
  }

  OrderRow copyWith(
          {String? clientOrderId,
          String? locationId,
          String? currencyCode,
          String? status,
          String? orderType,
          Value<String?> tableLabel = const Value.absent(),
          DateTime? createdAt,
          String? opsStatus,
          String? channel,
          String? source,
          Value<int?> guests = const Value.absent(),
          String? serverName,
          String? notes,
          double? discountPct,
          double? taxPct,
          Value<int?> billNo = const Value.absent(),
          Value<String?> paymentMethod = const Value.absent(),
          Value<DateTime?> settledAt = const Value.absent(),
          String? customerName,
          Value<String?> displayNo = const Value.absent()}) =>
      OrderRow(
        clientOrderId: clientOrderId ?? this.clientOrderId,
        locationId: locationId ?? this.locationId,
        currencyCode: currencyCode ?? this.currencyCode,
        status: status ?? this.status,
        orderType: orderType ?? this.orderType,
        tableLabel: tableLabel.present ? tableLabel.value : this.tableLabel,
        createdAt: createdAt ?? this.createdAt,
        opsStatus: opsStatus ?? this.opsStatus,
        channel: channel ?? this.channel,
        source: source ?? this.source,
        guests: guests.present ? guests.value : this.guests,
        serverName: serverName ?? this.serverName,
        notes: notes ?? this.notes,
        discountPct: discountPct ?? this.discountPct,
        taxPct: taxPct ?? this.taxPct,
        billNo: billNo.present ? billNo.value : this.billNo,
        paymentMethod:
            paymentMethod.present ? paymentMethod.value : this.paymentMethod,
        settledAt: settledAt.present ? settledAt.value : this.settledAt,
        customerName: customerName ?? this.customerName,
        displayNo: displayNo.present ? displayNo.value : this.displayNo,
      );
  OrderRow copyWithCompanion(OrdersCompanion data) {
    return OrderRow(
      clientOrderId: data.clientOrderId.present
          ? data.clientOrderId.value
          : this.clientOrderId,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      status: data.status.present ? data.status.value : this.status,
      orderType: data.orderType.present ? data.orderType.value : this.orderType,
      tableLabel:
          data.tableLabel.present ? data.tableLabel.value : this.tableLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      opsStatus: data.opsStatus.present ? data.opsStatus.value : this.opsStatus,
      channel: data.channel.present ? data.channel.value : this.channel,
      source: data.source.present ? data.source.value : this.source,
      guests: data.guests.present ? data.guests.value : this.guests,
      serverName:
          data.serverName.present ? data.serverName.value : this.serverName,
      notes: data.notes.present ? data.notes.value : this.notes,
      discountPct:
          data.discountPct.present ? data.discountPct.value : this.discountPct,
      taxPct: data.taxPct.present ? data.taxPct.value : this.taxPct,
      billNo: data.billNo.present ? data.billNo.value : this.billNo,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      displayNo: data.displayNo.present ? data.displayNo.value : this.displayNo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderRow(')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('locationId: $locationId, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('status: $status, ')
          ..write('orderType: $orderType, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('opsStatus: $opsStatus, ')
          ..write('channel: $channel, ')
          ..write('source: $source, ')
          ..write('guests: $guests, ')
          ..write('serverName: $serverName, ')
          ..write('notes: $notes, ')
          ..write('discountPct: $discountPct, ')
          ..write('taxPct: $taxPct, ')
          ..write('billNo: $billNo, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('settledAt: $settledAt, ')
          ..write('customerName: $customerName, ')
          ..write('displayNo: $displayNo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientOrderId,
      locationId,
      currencyCode,
      status,
      orderType,
      tableLabel,
      createdAt,
      opsStatus,
      channel,
      source,
      guests,
      serverName,
      notes,
      discountPct,
      taxPct,
      billNo,
      paymentMethod,
      settledAt,
      customerName,
      displayNo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderRow &&
          other.clientOrderId == this.clientOrderId &&
          other.locationId == this.locationId &&
          other.currencyCode == this.currencyCode &&
          other.status == this.status &&
          other.orderType == this.orderType &&
          other.tableLabel == this.tableLabel &&
          other.createdAt == this.createdAt &&
          other.opsStatus == this.opsStatus &&
          other.channel == this.channel &&
          other.source == this.source &&
          other.guests == this.guests &&
          other.serverName == this.serverName &&
          other.notes == this.notes &&
          other.discountPct == this.discountPct &&
          other.taxPct == this.taxPct &&
          other.billNo == this.billNo &&
          other.paymentMethod == this.paymentMethod &&
          other.settledAt == this.settledAt &&
          other.customerName == this.customerName &&
          other.displayNo == this.displayNo);
}

class OrdersCompanion extends UpdateCompanion<OrderRow> {
  final Value<String> clientOrderId;
  final Value<String> locationId;
  final Value<String> currencyCode;
  final Value<String> status;
  final Value<String> orderType;
  final Value<String?> tableLabel;
  final Value<DateTime> createdAt;
  final Value<String> opsStatus;
  final Value<String> channel;
  final Value<String> source;
  final Value<int?> guests;
  final Value<String> serverName;
  final Value<String> notes;
  final Value<double> discountPct;
  final Value<double> taxPct;
  final Value<int?> billNo;
  final Value<String?> paymentMethod;
  final Value<DateTime?> settledAt;
  final Value<String> customerName;
  final Value<String?> displayNo;
  final Value<int> rowid;
  const OrdersCompanion({
    this.clientOrderId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.status = const Value.absent(),
    this.orderType = const Value.absent(),
    this.tableLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.opsStatus = const Value.absent(),
    this.channel = const Value.absent(),
    this.source = const Value.absent(),
    this.guests = const Value.absent(),
    this.serverName = const Value.absent(),
    this.notes = const Value.absent(),
    this.discountPct = const Value.absent(),
    this.taxPct = const Value.absent(),
    this.billNo = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.customerName = const Value.absent(),
    this.displayNo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrdersCompanion.insert({
    required String clientOrderId,
    required String locationId,
    required String currencyCode,
    required String status,
    required String orderType,
    this.tableLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.opsStatus = const Value.absent(),
    this.channel = const Value.absent(),
    this.source = const Value.absent(),
    this.guests = const Value.absent(),
    this.serverName = const Value.absent(),
    this.notes = const Value.absent(),
    this.discountPct = const Value.absent(),
    this.taxPct = const Value.absent(),
    this.billNo = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.customerName = const Value.absent(),
    this.displayNo = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientOrderId = Value(clientOrderId),
        locationId = Value(locationId),
        currencyCode = Value(currencyCode),
        status = Value(status),
        orderType = Value(orderType);
  static Insertable<OrderRow> custom({
    Expression<String>? clientOrderId,
    Expression<String>? locationId,
    Expression<String>? currencyCode,
    Expression<String>? status,
    Expression<String>? orderType,
    Expression<String>? tableLabel,
    Expression<DateTime>? createdAt,
    Expression<String>? opsStatus,
    Expression<String>? channel,
    Expression<String>? source,
    Expression<int>? guests,
    Expression<String>? serverName,
    Expression<String>? notes,
    Expression<double>? discountPct,
    Expression<double>? taxPct,
    Expression<int>? billNo,
    Expression<String>? paymentMethod,
    Expression<DateTime>? settledAt,
    Expression<String>? customerName,
    Expression<String>? displayNo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientOrderId != null) 'client_order_id': clientOrderId,
      if (locationId != null) 'location_id': locationId,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (status != null) 'status': status,
      if (orderType != null) 'order_type': orderType,
      if (tableLabel != null) 'table_label': tableLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (opsStatus != null) 'ops_status': opsStatus,
      if (channel != null) 'channel': channel,
      if (source != null) 'source': source,
      if (guests != null) 'guests': guests,
      if (serverName != null) 'server_name': serverName,
      if (notes != null) 'notes': notes,
      if (discountPct != null) 'discount_pct': discountPct,
      if (taxPct != null) 'tax_pct': taxPct,
      if (billNo != null) 'bill_no': billNo,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (settledAt != null) 'settled_at': settledAt,
      if (customerName != null) 'customer_name': customerName,
      if (displayNo != null) 'display_no': displayNo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrdersCompanion copyWith(
      {Value<String>? clientOrderId,
      Value<String>? locationId,
      Value<String>? currencyCode,
      Value<String>? status,
      Value<String>? orderType,
      Value<String?>? tableLabel,
      Value<DateTime>? createdAt,
      Value<String>? opsStatus,
      Value<String>? channel,
      Value<String>? source,
      Value<int?>? guests,
      Value<String>? serverName,
      Value<String>? notes,
      Value<double>? discountPct,
      Value<double>? taxPct,
      Value<int?>? billNo,
      Value<String?>? paymentMethod,
      Value<DateTime?>? settledAt,
      Value<String>? customerName,
      Value<String?>? displayNo,
      Value<int>? rowid}) {
    return OrdersCompanion(
      clientOrderId: clientOrderId ?? this.clientOrderId,
      locationId: locationId ?? this.locationId,
      currencyCode: currencyCode ?? this.currencyCode,
      status: status ?? this.status,
      orderType: orderType ?? this.orderType,
      tableLabel: tableLabel ?? this.tableLabel,
      createdAt: createdAt ?? this.createdAt,
      opsStatus: opsStatus ?? this.opsStatus,
      channel: channel ?? this.channel,
      source: source ?? this.source,
      guests: guests ?? this.guests,
      serverName: serverName ?? this.serverName,
      notes: notes ?? this.notes,
      discountPct: discountPct ?? this.discountPct,
      taxPct: taxPct ?? this.taxPct,
      billNo: billNo ?? this.billNo,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      settledAt: settledAt ?? this.settledAt,
      customerName: customerName ?? this.customerName,
      displayNo: displayNo ?? this.displayNo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientOrderId.present) {
      map['client_order_id'] = Variable<String>(clientOrderId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (orderType.present) {
      map['order_type'] = Variable<String>(orderType.value);
    }
    if (tableLabel.present) {
      map['table_label'] = Variable<String>(tableLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (opsStatus.present) {
      map['ops_status'] = Variable<String>(opsStatus.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (guests.present) {
      map['guests'] = Variable<int>(guests.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (discountPct.present) {
      map['discount_pct'] = Variable<double>(discountPct.value);
    }
    if (taxPct.present) {
      map['tax_pct'] = Variable<double>(taxPct.value);
    }
    if (billNo.present) {
      map['bill_no'] = Variable<int>(billNo.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<DateTime>(settledAt.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (displayNo.present) {
      map['display_no'] = Variable<String>(displayNo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('locationId: $locationId, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('status: $status, ')
          ..write('orderType: $orderType, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('opsStatus: $opsStatus, ')
          ..write('channel: $channel, ')
          ..write('source: $source, ')
          ..write('guests: $guests, ')
          ..write('serverName: $serverName, ')
          ..write('notes: $notes, ')
          ..write('discountPct: $discountPct, ')
          ..write('taxPct: $taxPct, ')
          ..write('billNo: $billNo, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('settledAt: $settledAt, ')
          ..write('customerName: $customerName, ')
          ..write('displayNo: $displayNo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderLinesTable extends OrderLines
    with TableInfo<$OrderLinesTable, OrderLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientOrderIdMeta =
      const VerificationMeta('clientOrderId');
  @override
  late final GeneratedColumn<String> clientOrderId = GeneratedColumn<String>(
      'client_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMinorMeta =
      const VerificationMeta('unitMinor');
  @override
  late final GeneratedColumn<int> unitMinor = GeneratedColumn<int>(
      'unit_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stationMeta =
      const VerificationMeta('station');
  @override
  late final GeneratedColumn<String> station = GeneratedColumn<String>(
      'station', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Main Kitchen'));
  static const VerificationMeta _isVegMeta = const VerificationMeta('isVeg');
  @override
  late final GeneratedColumn<bool> isVeg = GeneratedColumn<bool>(
      'is_veg', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_veg" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _kitchenDoneMeta =
      const VerificationMeta('kitchenDone');
  @override
  late final GeneratedColumn<bool> kitchenDone = GeneratedColumn<bool>(
      'kitchen_done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("kitchen_done" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        clientOrderId,
        itemId,
        name,
        unitMinor,
        quantity,
        station,
        isVeg,
        kitchenDone
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_lines';
  @override
  VerificationContext validateIntegrity(Insertable<OrderLineRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_order_id')) {
      context.handle(
          _clientOrderIdMeta,
          clientOrderId.isAcceptableOrUnknown(
              data['client_order_id']!, _clientOrderIdMeta));
    } else if (isInserting) {
      context.missing(_clientOrderIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit_minor')) {
      context.handle(_unitMinorMeta,
          unitMinor.isAcceptableOrUnknown(data['unit_minor']!, _unitMinorMeta));
    } else if (isInserting) {
      context.missing(_unitMinorMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('station')) {
      context.handle(_stationMeta,
          station.isAcceptableOrUnknown(data['station']!, _stationMeta));
    }
    if (data.containsKey('is_veg')) {
      context.handle(
          _isVegMeta, isVeg.isAcceptableOrUnknown(data['is_veg']!, _isVegMeta));
    }
    if (data.containsKey('kitchen_done')) {
      context.handle(
          _kitchenDoneMeta,
          kitchenDone.isAcceptableOrUnknown(
              data['kitchen_done']!, _kitchenDoneMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientOrderId, itemId};
  @override
  OrderLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderLineRow(
      clientOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_order_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      unitMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unit_minor'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      station: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station'])!,
      isVeg: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_veg'])!,
      kitchenDone: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}kitchen_done'])!,
    );
  }

  @override
  $OrderLinesTable createAlias(String alias) {
    return $OrderLinesTable(attachedDatabase, alias);
  }
}

class OrderLineRow extends DataClass implements Insertable<OrderLineRow> {
  final String clientOrderId;
  final String itemId;
  final String name;
  final int unitMinor;
  final int quantity;
  final String station;
  final bool isVeg;
  final bool kitchenDone;
  const OrderLineRow(
      {required this.clientOrderId,
      required this.itemId,
      required this.name,
      required this.unitMinor,
      required this.quantity,
      required this.station,
      required this.isVeg,
      required this.kitchenDone});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_order_id'] = Variable<String>(clientOrderId);
    map['item_id'] = Variable<String>(itemId);
    map['name'] = Variable<String>(name);
    map['unit_minor'] = Variable<int>(unitMinor);
    map['quantity'] = Variable<int>(quantity);
    map['station'] = Variable<String>(station);
    map['is_veg'] = Variable<bool>(isVeg);
    map['kitchen_done'] = Variable<bool>(kitchenDone);
    return map;
  }

  OrderLinesCompanion toCompanion(bool nullToAbsent) {
    return OrderLinesCompanion(
      clientOrderId: Value(clientOrderId),
      itemId: Value(itemId),
      name: Value(name),
      unitMinor: Value(unitMinor),
      quantity: Value(quantity),
      station: Value(station),
      isVeg: Value(isVeg),
      kitchenDone: Value(kitchenDone),
    );
  }

  factory OrderLineRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderLineRow(
      clientOrderId: serializer.fromJson<String>(json['clientOrderId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      name: serializer.fromJson<String>(json['name']),
      unitMinor: serializer.fromJson<int>(json['unitMinor']),
      quantity: serializer.fromJson<int>(json['quantity']),
      station: serializer.fromJson<String>(json['station']),
      isVeg: serializer.fromJson<bool>(json['isVeg']),
      kitchenDone: serializer.fromJson<bool>(json['kitchenDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientOrderId': serializer.toJson<String>(clientOrderId),
      'itemId': serializer.toJson<String>(itemId),
      'name': serializer.toJson<String>(name),
      'unitMinor': serializer.toJson<int>(unitMinor),
      'quantity': serializer.toJson<int>(quantity),
      'station': serializer.toJson<String>(station),
      'isVeg': serializer.toJson<bool>(isVeg),
      'kitchenDone': serializer.toJson<bool>(kitchenDone),
    };
  }

  OrderLineRow copyWith(
          {String? clientOrderId,
          String? itemId,
          String? name,
          int? unitMinor,
          int? quantity,
          String? station,
          bool? isVeg,
          bool? kitchenDone}) =>
      OrderLineRow(
        clientOrderId: clientOrderId ?? this.clientOrderId,
        itemId: itemId ?? this.itemId,
        name: name ?? this.name,
        unitMinor: unitMinor ?? this.unitMinor,
        quantity: quantity ?? this.quantity,
        station: station ?? this.station,
        isVeg: isVeg ?? this.isVeg,
        kitchenDone: kitchenDone ?? this.kitchenDone,
      );
  OrderLineRow copyWithCompanion(OrderLinesCompanion data) {
    return OrderLineRow(
      clientOrderId: data.clientOrderId.present
          ? data.clientOrderId.value
          : this.clientOrderId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      name: data.name.present ? data.name.value : this.name,
      unitMinor: data.unitMinor.present ? data.unitMinor.value : this.unitMinor,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      station: data.station.present ? data.station.value : this.station,
      isVeg: data.isVeg.present ? data.isVeg.value : this.isVeg,
      kitchenDone:
          data.kitchenDone.present ? data.kitchenDone.value : this.kitchenDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderLineRow(')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('unitMinor: $unitMinor, ')
          ..write('quantity: $quantity, ')
          ..write('station: $station, ')
          ..write('isVeg: $isVeg, ')
          ..write('kitchenDone: $kitchenDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientOrderId, itemId, name, unitMinor,
      quantity, station, isVeg, kitchenDone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderLineRow &&
          other.clientOrderId == this.clientOrderId &&
          other.itemId == this.itemId &&
          other.name == this.name &&
          other.unitMinor == this.unitMinor &&
          other.quantity == this.quantity &&
          other.station == this.station &&
          other.isVeg == this.isVeg &&
          other.kitchenDone == this.kitchenDone);
}

class OrderLinesCompanion extends UpdateCompanion<OrderLineRow> {
  final Value<String> clientOrderId;
  final Value<String> itemId;
  final Value<String> name;
  final Value<int> unitMinor;
  final Value<int> quantity;
  final Value<String> station;
  final Value<bool> isVeg;
  final Value<bool> kitchenDone;
  final Value<int> rowid;
  const OrderLinesCompanion({
    this.clientOrderId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.name = const Value.absent(),
    this.unitMinor = const Value.absent(),
    this.quantity = const Value.absent(),
    this.station = const Value.absent(),
    this.isVeg = const Value.absent(),
    this.kitchenDone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderLinesCompanion.insert({
    required String clientOrderId,
    required String itemId,
    required String name,
    required int unitMinor,
    required int quantity,
    this.station = const Value.absent(),
    this.isVeg = const Value.absent(),
    this.kitchenDone = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientOrderId = Value(clientOrderId),
        itemId = Value(itemId),
        name = Value(name),
        unitMinor = Value(unitMinor),
        quantity = Value(quantity);
  static Insertable<OrderLineRow> custom({
    Expression<String>? clientOrderId,
    Expression<String>? itemId,
    Expression<String>? name,
    Expression<int>? unitMinor,
    Expression<int>? quantity,
    Expression<String>? station,
    Expression<bool>? isVeg,
    Expression<bool>? kitchenDone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientOrderId != null) 'client_order_id': clientOrderId,
      if (itemId != null) 'item_id': itemId,
      if (name != null) 'name': name,
      if (unitMinor != null) 'unit_minor': unitMinor,
      if (quantity != null) 'quantity': quantity,
      if (station != null) 'station': station,
      if (isVeg != null) 'is_veg': isVeg,
      if (kitchenDone != null) 'kitchen_done': kitchenDone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderLinesCompanion copyWith(
      {Value<String>? clientOrderId,
      Value<String>? itemId,
      Value<String>? name,
      Value<int>? unitMinor,
      Value<int>? quantity,
      Value<String>? station,
      Value<bool>? isVeg,
      Value<bool>? kitchenDone,
      Value<int>? rowid}) {
    return OrderLinesCompanion(
      clientOrderId: clientOrderId ?? this.clientOrderId,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      unitMinor: unitMinor ?? this.unitMinor,
      quantity: quantity ?? this.quantity,
      station: station ?? this.station,
      isVeg: isVeg ?? this.isVeg,
      kitchenDone: kitchenDone ?? this.kitchenDone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientOrderId.present) {
      map['client_order_id'] = Variable<String>(clientOrderId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unitMinor.present) {
      map['unit_minor'] = Variable<int>(unitMinor.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (station.present) {
      map['station'] = Variable<String>(station.value);
    }
    if (isVeg.present) {
      map['is_veg'] = Variable<bool>(isVeg.value);
    }
    if (kitchenDone.present) {
      map['kitchen_done'] = Variable<bool>(kitchenDone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderLinesCompanion(')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('unitMinor: $unitMinor, ')
          ..write('quantity: $quantity, ')
          ..write('station: $station, ')
          ..write('isVeg: $isVeg, ')
          ..write('kitchenDone: $kitchenDone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingUploadIntentsTable extends PendingUploadIntents
    with TableInfo<$PendingUploadIntentsTable, PendingUploadIntentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingUploadIntentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _intentIdMeta =
      const VerificationMeta('intentId');
  @override
  late final GeneratedColumn<String> intentId = GeneratedColumn<String>(
      'intent_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientOrderIdMeta =
      const VerificationMeta('clientOrderId');
  @override
  late final GeneratedColumn<String> clientOrderId = GeneratedColumn<String>(
      'client_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadHashMeta =
      const VerificationMeta('payloadHash');
  @override
  late final GeneratedColumn<String> payloadHash = GeneratedColumn<String>(
      'payload_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('queued'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        intentId,
        clientOrderId,
        operation,
        payloadHash,
        state,
        retryCount,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_upload_intents';
  @override
  VerificationContext validateIntegrity(
      Insertable<PendingUploadIntentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('intent_id')) {
      context.handle(_intentIdMeta,
          intentId.isAcceptableOrUnknown(data['intent_id']!, _intentIdMeta));
    } else if (isInserting) {
      context.missing(_intentIdMeta);
    }
    if (data.containsKey('client_order_id')) {
      context.handle(
          _clientOrderIdMeta,
          clientOrderId.isAcceptableOrUnknown(
              data['client_order_id']!, _clientOrderIdMeta));
    } else if (isInserting) {
      context.missing(_clientOrderIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_hash')) {
      context.handle(
          _payloadHashMeta,
          payloadHash.isAcceptableOrUnknown(
              data['payload_hash']!, _payloadHashMeta));
    } else if (isInserting) {
      context.missing(_payloadHashMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {intentId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {clientOrderId, operation},
      ];
  @override
  PendingUploadIntentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUploadIntentRow(
      intentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}intent_id'])!,
      clientOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_order_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payloadHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_hash'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PendingUploadIntentsTable createAlias(String alias) {
    return $PendingUploadIntentsTable(attachedDatabase, alias);
  }
}

class PendingUploadIntentRow extends DataClass
    implements Insertable<PendingUploadIntentRow> {
  final String intentId;
  final String clientOrderId;
  final String operation;
  final String payloadHash;
  final String state;
  final int retryCount;
  final DateTime createdAt;
  const PendingUploadIntentRow(
      {required this.intentId,
      required this.clientOrderId,
      required this.operation,
      required this.payloadHash,
      required this.state,
      required this.retryCount,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['intent_id'] = Variable<String>(intentId);
    map['client_order_id'] = Variable<String>(clientOrderId);
    map['operation'] = Variable<String>(operation);
    map['payload_hash'] = Variable<String>(payloadHash);
    map['state'] = Variable<String>(state);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingUploadIntentsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadIntentsCompanion(
      intentId: Value(intentId),
      clientOrderId: Value(clientOrderId),
      operation: Value(operation),
      payloadHash: Value(payloadHash),
      state: Value(state),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory PendingUploadIntentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUploadIntentRow(
      intentId: serializer.fromJson<String>(json['intentId']),
      clientOrderId: serializer.fromJson<String>(json['clientOrderId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadHash: serializer.fromJson<String>(json['payloadHash']),
      state: serializer.fromJson<String>(json['state']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'intentId': serializer.toJson<String>(intentId),
      'clientOrderId': serializer.toJson<String>(clientOrderId),
      'operation': serializer.toJson<String>(operation),
      'payloadHash': serializer.toJson<String>(payloadHash),
      'state': serializer.toJson<String>(state),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingUploadIntentRow copyWith(
          {String? intentId,
          String? clientOrderId,
          String? operation,
          String? payloadHash,
          String? state,
          int? retryCount,
          DateTime? createdAt}) =>
      PendingUploadIntentRow(
        intentId: intentId ?? this.intentId,
        clientOrderId: clientOrderId ?? this.clientOrderId,
        operation: operation ?? this.operation,
        payloadHash: payloadHash ?? this.payloadHash,
        state: state ?? this.state,
        retryCount: retryCount ?? this.retryCount,
        createdAt: createdAt ?? this.createdAt,
      );
  PendingUploadIntentRow copyWithCompanion(PendingUploadIntentsCompanion data) {
    return PendingUploadIntentRow(
      intentId: data.intentId.present ? data.intentId.value : this.intentId,
      clientOrderId: data.clientOrderId.present
          ? data.clientOrderId.value
          : this.clientOrderId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadHash:
          data.payloadHash.present ? data.payloadHash.value : this.payloadHash,
      state: data.state.present ? data.state.value : this.state,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadIntentRow(')
          ..write('intentId: $intentId, ')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('operation: $operation, ')
          ..write('payloadHash: $payloadHash, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(intentId, clientOrderId, operation,
      payloadHash, state, retryCount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUploadIntentRow &&
          other.intentId == this.intentId &&
          other.clientOrderId == this.clientOrderId &&
          other.operation == this.operation &&
          other.payloadHash == this.payloadHash &&
          other.state == this.state &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class PendingUploadIntentsCompanion
    extends UpdateCompanion<PendingUploadIntentRow> {
  final Value<String> intentId;
  final Value<String> clientOrderId;
  final Value<String> operation;
  final Value<String> payloadHash;
  final Value<String> state;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingUploadIntentsCompanion({
    this.intentId = const Value.absent(),
    this.clientOrderId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadHash = const Value.absent(),
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingUploadIntentsCompanion.insert({
    required String intentId,
    required String clientOrderId,
    required String operation,
    required String payloadHash,
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : intentId = Value(intentId),
        clientOrderId = Value(clientOrderId),
        operation = Value(operation),
        payloadHash = Value(payloadHash);
  static Insertable<PendingUploadIntentRow> custom({
    Expression<String>? intentId,
    Expression<String>? clientOrderId,
    Expression<String>? operation,
    Expression<String>? payloadHash,
    Expression<String>? state,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (intentId != null) 'intent_id': intentId,
      if (clientOrderId != null) 'client_order_id': clientOrderId,
      if (operation != null) 'operation': operation,
      if (payloadHash != null) 'payload_hash': payloadHash,
      if (state != null) 'state': state,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingUploadIntentsCompanion copyWith(
      {Value<String>? intentId,
      Value<String>? clientOrderId,
      Value<String>? operation,
      Value<String>? payloadHash,
      Value<String>? state,
      Value<int>? retryCount,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PendingUploadIntentsCompanion(
      intentId: intentId ?? this.intentId,
      clientOrderId: clientOrderId ?? this.clientOrderId,
      operation: operation ?? this.operation,
      payloadHash: payloadHash ?? this.payloadHash,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (intentId.present) {
      map['intent_id'] = Variable<String>(intentId.value);
    }
    if (clientOrderId.present) {
      map['client_order_id'] = Variable<String>(clientOrderId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadHash.present) {
      map['payload_hash'] = Variable<String>(payloadHash.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadIntentsCompanion(')
          ..write('intentId: $intentId, ')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('operation: $operation, ')
          ..write('payloadHash: $payloadHash, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KitchenTicketsTable extends KitchenTickets
    with TableInfo<$KitchenTicketsTable, KitchenTicketRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KitchenTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ticketIdMeta =
      const VerificationMeta('ticketId');
  @override
  late final GeneratedColumn<String> ticketId = GeneratedColumn<String>(
      'ticket_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientOrderIdMeta =
      const VerificationMeta('clientOrderId');
  @override
  late final GeneratedColumn<String> clientOrderId = GeneratedColumn<String>(
      'client_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _urgentMeta = const VerificationMeta('urgent');
  @override
  late final GeneratedColumn<bool> urgent = GeneratedColumn<bool>(
      'urgent', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("urgent" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _kotNoMeta = const VerificationMeta('kotNo');
  @override
  late final GeneratedColumn<int> kotNo = GeneratedColumn<int>(
      'kot_no', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        ticketId,
        clientOrderId,
        status,
        createdAt,
        notes,
        urgent,
        completedAt,
        kotNo
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kitchen_tickets';
  @override
  VerificationContext validateIntegrity(Insertable<KitchenTicketRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ticket_id')) {
      context.handle(_ticketIdMeta,
          ticketId.isAcceptableOrUnknown(data['ticket_id']!, _ticketIdMeta));
    } else if (isInserting) {
      context.missing(_ticketIdMeta);
    }
    if (data.containsKey('client_order_id')) {
      context.handle(
          _clientOrderIdMeta,
          clientOrderId.isAcceptableOrUnknown(
              data['client_order_id']!, _clientOrderIdMeta));
    } else if (isInserting) {
      context.missing(_clientOrderIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('urgent')) {
      context.handle(_urgentMeta,
          urgent.isAcceptableOrUnknown(data['urgent']!, _urgentMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('kot_no')) {
      context.handle(
          _kotNoMeta, kotNo.isAcceptableOrUnknown(data['kot_no']!, _kotNoMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ticketId};
  @override
  KitchenTicketRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KitchenTicketRow(
      ticketId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ticket_id'])!,
      clientOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_order_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      urgent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}urgent'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      kotNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}kot_no']),
    );
  }

  @override
  $KitchenTicketsTable createAlias(String alias) {
    return $KitchenTicketsTable(attachedDatabase, alias);
  }
}

class KitchenTicketRow extends DataClass
    implements Insertable<KitchenTicketRow> {
  final String ticketId;
  final String clientOrderId;
  final String status;
  final DateTime createdAt;
  final String notes;
  final bool urgent;
  final DateTime? completedAt;
  final int? kotNo;
  const KitchenTicketRow(
      {required this.ticketId,
      required this.clientOrderId,
      required this.status,
      required this.createdAt,
      required this.notes,
      required this.urgent,
      this.completedAt,
      this.kotNo});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ticket_id'] = Variable<String>(ticketId);
    map['client_order_id'] = Variable<String>(clientOrderId);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['notes'] = Variable<String>(notes);
    map['urgent'] = Variable<bool>(urgent);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || kotNo != null) {
      map['kot_no'] = Variable<int>(kotNo);
    }
    return map;
  }

  KitchenTicketsCompanion toCompanion(bool nullToAbsent) {
    return KitchenTicketsCompanion(
      ticketId: Value(ticketId),
      clientOrderId: Value(clientOrderId),
      status: Value(status),
      createdAt: Value(createdAt),
      notes: Value(notes),
      urgent: Value(urgent),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      kotNo:
          kotNo == null && nullToAbsent ? const Value.absent() : Value(kotNo),
    );
  }

  factory KitchenTicketRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KitchenTicketRow(
      ticketId: serializer.fromJson<String>(json['ticketId']),
      clientOrderId: serializer.fromJson<String>(json['clientOrderId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      notes: serializer.fromJson<String>(json['notes']),
      urgent: serializer.fromJson<bool>(json['urgent']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      kotNo: serializer.fromJson<int?>(json['kotNo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ticketId': serializer.toJson<String>(ticketId),
      'clientOrderId': serializer.toJson<String>(clientOrderId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'notes': serializer.toJson<String>(notes),
      'urgent': serializer.toJson<bool>(urgent),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'kotNo': serializer.toJson<int?>(kotNo),
    };
  }

  KitchenTicketRow copyWith(
          {String? ticketId,
          String? clientOrderId,
          String? status,
          DateTime? createdAt,
          String? notes,
          bool? urgent,
          Value<DateTime?> completedAt = const Value.absent(),
          Value<int?> kotNo = const Value.absent()}) =>
      KitchenTicketRow(
        ticketId: ticketId ?? this.ticketId,
        clientOrderId: clientOrderId ?? this.clientOrderId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        notes: notes ?? this.notes,
        urgent: urgent ?? this.urgent,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        kotNo: kotNo.present ? kotNo.value : this.kotNo,
      );
  KitchenTicketRow copyWithCompanion(KitchenTicketsCompanion data) {
    return KitchenTicketRow(
      ticketId: data.ticketId.present ? data.ticketId.value : this.ticketId,
      clientOrderId: data.clientOrderId.present
          ? data.clientOrderId.value
          : this.clientOrderId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      urgent: data.urgent.present ? data.urgent.value : this.urgent,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      kotNo: data.kotNo.present ? data.kotNo.value : this.kotNo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KitchenTicketRow(')
          ..write('ticketId: $ticketId, ')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('urgent: $urgent, ')
          ..write('completedAt: $completedAt, ')
          ..write('kotNo: $kotNo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ticketId, clientOrderId, status, createdAt,
      notes, urgent, completedAt, kotNo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KitchenTicketRow &&
          other.ticketId == this.ticketId &&
          other.clientOrderId == this.clientOrderId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.notes == this.notes &&
          other.urgent == this.urgent &&
          other.completedAt == this.completedAt &&
          other.kotNo == this.kotNo);
}

class KitchenTicketsCompanion extends UpdateCompanion<KitchenTicketRow> {
  final Value<String> ticketId;
  final Value<String> clientOrderId;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String> notes;
  final Value<bool> urgent;
  final Value<DateTime?> completedAt;
  final Value<int?> kotNo;
  final Value<int> rowid;
  const KitchenTicketsCompanion({
    this.ticketId = const Value.absent(),
    this.clientOrderId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.urgent = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.kotNo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KitchenTicketsCompanion.insert({
    required String ticketId,
    required String clientOrderId,
    required String status,
    this.createdAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.urgent = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.kotNo = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : ticketId = Value(ticketId),
        clientOrderId = Value(clientOrderId),
        status = Value(status);
  static Insertable<KitchenTicketRow> custom({
    Expression<String>? ticketId,
    Expression<String>? clientOrderId,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? notes,
    Expression<bool>? urgent,
    Expression<DateTime>? completedAt,
    Expression<int>? kotNo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ticketId != null) 'ticket_id': ticketId,
      if (clientOrderId != null) 'client_order_id': clientOrderId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (notes != null) 'notes': notes,
      if (urgent != null) 'urgent': urgent,
      if (completedAt != null) 'completed_at': completedAt,
      if (kotNo != null) 'kot_no': kotNo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KitchenTicketsCompanion copyWith(
      {Value<String>? ticketId,
      Value<String>? clientOrderId,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<String>? notes,
      Value<bool>? urgent,
      Value<DateTime?>? completedAt,
      Value<int?>? kotNo,
      Value<int>? rowid}) {
    return KitchenTicketsCompanion(
      ticketId: ticketId ?? this.ticketId,
      clientOrderId: clientOrderId ?? this.clientOrderId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      urgent: urgent ?? this.urgent,
      completedAt: completedAt ?? this.completedAt,
      kotNo: kotNo ?? this.kotNo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ticketId.present) {
      map['ticket_id'] = Variable<String>(ticketId.value);
    }
    if (clientOrderId.present) {
      map['client_order_id'] = Variable<String>(clientOrderId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (urgent.present) {
      map['urgent'] = Variable<bool>(urgent.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (kotNo.present) {
      map['kot_no'] = Variable<int>(kotNo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KitchenTicketsCompanion(')
          ..write('ticketId: $ticketId, ')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('urgent: $urgent, ')
          ..write('completedAt: $completedAt, ')
          ..write('kotNo: $kotNo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShiftsTable extends Shifts with TableInfo<$ShiftsTable, ShiftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _shiftIdMeta =
      const VerificationMeta('shiftId');
  @override
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
      'shift_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _openingFloatMinorMeta =
      const VerificationMeta('openingFloatMinor');
  @override
  late final GeneratedColumn<int> openingFloatMinor = GeneratedColumn<int>(
      'opening_float_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _openedAtMeta =
      const VerificationMeta('openedAt');
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
      'opened_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _closedAtMeta =
      const VerificationMeta('closedAt');
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
      'closed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _countedCashMinorMeta =
      const VerificationMeta('countedCashMinor');
  @override
  late final GeneratedColumn<int> countedCashMinor = GeneratedColumn<int>(
      'counted_cash_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        shiftId,
        locationId,
        openingFloatMinor,
        openedAt,
        closedAt,
        countedCashMinor
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  VerificationContext validateIntegrity(Insertable<ShiftRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('shift_id')) {
      context.handle(_shiftIdMeta,
          shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta));
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('opening_float_minor')) {
      context.handle(
          _openingFloatMinorMeta,
          openingFloatMinor.isAcceptableOrUnknown(
              data['opening_float_minor']!, _openingFloatMinorMeta));
    } else if (isInserting) {
      context.missing(_openingFloatMinorMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(_openedAtMeta,
          openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta));
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(_closedAtMeta,
          closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta));
    }
    if (data.containsKey('counted_cash_minor')) {
      context.handle(
          _countedCashMinorMeta,
          countedCashMinor.isAcceptableOrUnknown(
              data['counted_cash_minor']!, _countedCashMinorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {shiftId};
  @override
  ShiftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftRow(
      shiftId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shift_id'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id'])!,
      openingFloatMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}opening_float_minor'])!,
      openedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}opened_at'])!,
      closedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}closed_at']),
      countedCashMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}counted_cash_minor']),
    );
  }

  @override
  $ShiftsTable createAlias(String alias) {
    return $ShiftsTable(attachedDatabase, alias);
  }
}

class ShiftRow extends DataClass implements Insertable<ShiftRow> {
  final String shiftId;
  final String locationId;
  final int openingFloatMinor;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int? countedCashMinor;
  const ShiftRow(
      {required this.shiftId,
      required this.locationId,
      required this.openingFloatMinor,
      required this.openedAt,
      this.closedAt,
      this.countedCashMinor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['shift_id'] = Variable<String>(shiftId);
    map['location_id'] = Variable<String>(locationId);
    map['opening_float_minor'] = Variable<int>(openingFloatMinor);
    map['opened_at'] = Variable<DateTime>(openedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || countedCashMinor != null) {
      map['counted_cash_minor'] = Variable<int>(countedCashMinor);
    }
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      shiftId: Value(shiftId),
      locationId: Value(locationId),
      openingFloatMinor: Value(openingFloatMinor),
      openedAt: Value(openedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      countedCashMinor: countedCashMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(countedCashMinor),
    );
  }

  factory ShiftRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftRow(
      shiftId: serializer.fromJson<String>(json['shiftId']),
      locationId: serializer.fromJson<String>(json['locationId']),
      openingFloatMinor: serializer.fromJson<int>(json['openingFloatMinor']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      countedCashMinor: serializer.fromJson<int?>(json['countedCashMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'shiftId': serializer.toJson<String>(shiftId),
      'locationId': serializer.toJson<String>(locationId),
      'openingFloatMinor': serializer.toJson<int>(openingFloatMinor),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'countedCashMinor': serializer.toJson<int?>(countedCashMinor),
    };
  }

  ShiftRow copyWith(
          {String? shiftId,
          String? locationId,
          int? openingFloatMinor,
          DateTime? openedAt,
          Value<DateTime?> closedAt = const Value.absent(),
          Value<int?> countedCashMinor = const Value.absent()}) =>
      ShiftRow(
        shiftId: shiftId ?? this.shiftId,
        locationId: locationId ?? this.locationId,
        openingFloatMinor: openingFloatMinor ?? this.openingFloatMinor,
        openedAt: openedAt ?? this.openedAt,
        closedAt: closedAt.present ? closedAt.value : this.closedAt,
        countedCashMinor: countedCashMinor.present
            ? countedCashMinor.value
            : this.countedCashMinor,
      );
  ShiftRow copyWithCompanion(ShiftsCompanion data) {
    return ShiftRow(
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      openingFloatMinor: data.openingFloatMinor.present
          ? data.openingFloatMinor.value
          : this.openingFloatMinor,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      countedCashMinor: data.countedCashMinor.present
          ? data.countedCashMinor.value
          : this.countedCashMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftRow(')
          ..write('shiftId: $shiftId, ')
          ..write('locationId: $locationId, ')
          ..write('openingFloatMinor: $openingFloatMinor, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('countedCashMinor: $countedCashMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(shiftId, locationId, openingFloatMinor,
      openedAt, closedAt, countedCashMinor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftRow &&
          other.shiftId == this.shiftId &&
          other.locationId == this.locationId &&
          other.openingFloatMinor == this.openingFloatMinor &&
          other.openedAt == this.openedAt &&
          other.closedAt == this.closedAt &&
          other.countedCashMinor == this.countedCashMinor);
}

class ShiftsCompanion extends UpdateCompanion<ShiftRow> {
  final Value<String> shiftId;
  final Value<String> locationId;
  final Value<int> openingFloatMinor;
  final Value<DateTime> openedAt;
  final Value<DateTime?> closedAt;
  final Value<int?> countedCashMinor;
  final Value<int> rowid;
  const ShiftsCompanion({
    this.shiftId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.openingFloatMinor = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.countedCashMinor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftsCompanion.insert({
    required String shiftId,
    required String locationId,
    required int openingFloatMinor,
    required DateTime openedAt,
    this.closedAt = const Value.absent(),
    this.countedCashMinor = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : shiftId = Value(shiftId),
        locationId = Value(locationId),
        openingFloatMinor = Value(openingFloatMinor),
        openedAt = Value(openedAt);
  static Insertable<ShiftRow> custom({
    Expression<String>? shiftId,
    Expression<String>? locationId,
    Expression<int>? openingFloatMinor,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? closedAt,
    Expression<int>? countedCashMinor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (shiftId != null) 'shift_id': shiftId,
      if (locationId != null) 'location_id': locationId,
      if (openingFloatMinor != null) 'opening_float_minor': openingFloatMinor,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (countedCashMinor != null) 'counted_cash_minor': countedCashMinor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftsCompanion copyWith(
      {Value<String>? shiftId,
      Value<String>? locationId,
      Value<int>? openingFloatMinor,
      Value<DateTime>? openedAt,
      Value<DateTime?>? closedAt,
      Value<int?>? countedCashMinor,
      Value<int>? rowid}) {
    return ShiftsCompanion(
      shiftId: shiftId ?? this.shiftId,
      locationId: locationId ?? this.locationId,
      openingFloatMinor: openingFloatMinor ?? this.openingFloatMinor,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      countedCashMinor: countedCashMinor ?? this.countedCashMinor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (openingFloatMinor.present) {
      map['opening_float_minor'] = Variable<int>(openingFloatMinor.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (countedCashMinor.present) {
      map['counted_cash_minor'] = Variable<int>(countedCashMinor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsCompanion(')
          ..write('shiftId: $shiftId, ')
          ..write('locationId: $locationId, ')
          ..write('openingFloatMinor: $openingFloatMinor, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('countedCashMinor: $countedCashMinor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments
    with TableInfo<$PaymentsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _paymentIdMeta =
      const VerificationMeta('paymentId');
  @override
  late final GeneratedColumn<String> paymentId = GeneratedColumn<String>(
      'payment_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientOrderIdMeta =
      const VerificationMeta('clientOrderId');
  @override
  late final GeneratedColumn<String> clientOrderId = GeneratedColumn<String>(
      'client_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
      'method', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _receivedMinorMeta =
      const VerificationMeta('receivedMinor');
  @override
  late final GeneratedColumn<int> receivedMinor = GeneratedColumn<int>(
      'received_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        paymentId,
        clientOrderId,
        method,
        amountMinor,
        receivedMinor,
        recordedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(Insertable<PaymentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('payment_id')) {
      context.handle(_paymentIdMeta,
          paymentId.isAcceptableOrUnknown(data['payment_id']!, _paymentIdMeta));
    } else if (isInserting) {
      context.missing(_paymentIdMeta);
    }
    if (data.containsKey('client_order_id')) {
      context.handle(
          _clientOrderIdMeta,
          clientOrderId.isAcceptableOrUnknown(
              data['client_order_id']!, _clientOrderIdMeta));
    } else if (isInserting) {
      context.missing(_clientOrderIdMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('received_minor')) {
      context.handle(
          _receivedMinorMeta,
          receivedMinor.isAcceptableOrUnknown(
              data['received_minor']!, _receivedMinorMeta));
    } else if (isInserting) {
      context.missing(_receivedMinorMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {paymentId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {clientOrderId},
      ];
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      paymentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_id'])!,
      clientOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_order_id'])!,
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method'])!,
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      receivedMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}received_minor'])!,
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String paymentId;
  final String clientOrderId;
  final String method;
  final int amountMinor;
  final int receivedMinor;
  final DateTime recordedAt;
  const PaymentRow(
      {required this.paymentId,
      required this.clientOrderId,
      required this.method,
      required this.amountMinor,
      required this.receivedMinor,
      required this.recordedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['payment_id'] = Variable<String>(paymentId);
    map['client_order_id'] = Variable<String>(clientOrderId);
    map['method'] = Variable<String>(method);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['received_minor'] = Variable<int>(receivedMinor);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      paymentId: Value(paymentId),
      clientOrderId: Value(clientOrderId),
      method: Value(method),
      amountMinor: Value(amountMinor),
      receivedMinor: Value(receivedMinor),
      recordedAt: Value(recordedAt),
    );
  }

  factory PaymentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      paymentId: serializer.fromJson<String>(json['paymentId']),
      clientOrderId: serializer.fromJson<String>(json['clientOrderId']),
      method: serializer.fromJson<String>(json['method']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      receivedMinor: serializer.fromJson<int>(json['receivedMinor']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'paymentId': serializer.toJson<String>(paymentId),
      'clientOrderId': serializer.toJson<String>(clientOrderId),
      'method': serializer.toJson<String>(method),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'receivedMinor': serializer.toJson<int>(receivedMinor),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  PaymentRow copyWith(
          {String? paymentId,
          String? clientOrderId,
          String? method,
          int? amountMinor,
          int? receivedMinor,
          DateTime? recordedAt}) =>
      PaymentRow(
        paymentId: paymentId ?? this.paymentId,
        clientOrderId: clientOrderId ?? this.clientOrderId,
        method: method ?? this.method,
        amountMinor: amountMinor ?? this.amountMinor,
        receivedMinor: receivedMinor ?? this.receivedMinor,
        recordedAt: recordedAt ?? this.recordedAt,
      );
  PaymentRow copyWithCompanion(PaymentsCompanion data) {
    return PaymentRow(
      paymentId: data.paymentId.present ? data.paymentId.value : this.paymentId,
      clientOrderId: data.clientOrderId.present
          ? data.clientOrderId.value
          : this.clientOrderId,
      method: data.method.present ? data.method.value : this.method,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      receivedMinor: data.receivedMinor.present
          ? data.receivedMinor.value
          : this.receivedMinor,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('paymentId: $paymentId, ')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('method: $method, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('receivedMinor: $receivedMinor, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      paymentId, clientOrderId, method, amountMinor, receivedMinor, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.paymentId == this.paymentId &&
          other.clientOrderId == this.clientOrderId &&
          other.method == this.method &&
          other.amountMinor == this.amountMinor &&
          other.receivedMinor == this.receivedMinor &&
          other.recordedAt == this.recordedAt);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> paymentId;
  final Value<String> clientOrderId;
  final Value<String> method;
  final Value<int> amountMinor;
  final Value<int> receivedMinor;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.paymentId = const Value.absent(),
    this.clientOrderId = const Value.absent(),
    this.method = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.receivedMinor = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String paymentId,
    required String clientOrderId,
    required String method,
    required int amountMinor,
    required int receivedMinor,
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : paymentId = Value(paymentId),
        clientOrderId = Value(clientOrderId),
        method = Value(method),
        amountMinor = Value(amountMinor),
        receivedMinor = Value(receivedMinor);
  static Insertable<PaymentRow> custom({
    Expression<String>? paymentId,
    Expression<String>? clientOrderId,
    Expression<String>? method,
    Expression<int>? amountMinor,
    Expression<int>? receivedMinor,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (paymentId != null) 'payment_id': paymentId,
      if (clientOrderId != null) 'client_order_id': clientOrderId,
      if (method != null) 'method': method,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (receivedMinor != null) 'received_minor': receivedMinor,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith(
      {Value<String>? paymentId,
      Value<String>? clientOrderId,
      Value<String>? method,
      Value<int>? amountMinor,
      Value<int>? receivedMinor,
      Value<DateTime>? recordedAt,
      Value<int>? rowid}) {
    return PaymentsCompanion(
      paymentId: paymentId ?? this.paymentId,
      clientOrderId: clientOrderId ?? this.clientOrderId,
      method: method ?? this.method,
      amountMinor: amountMinor ?? this.amountMinor,
      receivedMinor: receivedMinor ?? this.receivedMinor,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (paymentId.present) {
      map['payment_id'] = Variable<String>(paymentId.value);
    }
    if (clientOrderId.present) {
      map['client_order_id'] = Variable<String>(clientOrderId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (receivedMinor.present) {
      map['received_minor'] = Variable<int>(receivedMinor.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('paymentId: $paymentId, ')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('method: $method, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('receivedMinor: $receivedMinor, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceSessionsTable extends DeviceSessions
    with TableInfo<$DeviceSessionsTable, DeviceSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _staffIdMeta =
      const VerificationMeta('staffId');
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
      'staff_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _staffNameMeta =
      const VerificationMeta('staffName');
  @override
  late final GeneratedColumn<String> staffName = GeneratedColumn<String>(
      'staff_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _grantedAtMeta =
      const VerificationMeta('grantedAt');
  @override
  late final GeneratedColumn<DateTime> grantedAt = GeneratedColumn<DateTime>(
      'granted_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _grantExpiresAtMeta =
      const VerificationMeta('grantExpiresAt');
  @override
  late final GeneratedColumn<DateTime> grantExpiresAt =
      GeneratedColumn<DateTime>('grant_expires_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [deviceId, staffId, staffName, locationId, grantedAt, grantExpiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<DeviceSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('staff_id')) {
      context.handle(_staffIdMeta,
          staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta));
    } else if (isInserting) {
      context.missing(_staffIdMeta);
    }
    if (data.containsKey('staff_name')) {
      context.handle(_staffNameMeta,
          staffName.isAcceptableOrUnknown(data['staff_name']!, _staffNameMeta));
    } else if (isInserting) {
      context.missing(_staffNameMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('granted_at')) {
      context.handle(_grantedAtMeta,
          grantedAt.isAcceptableOrUnknown(data['granted_at']!, _grantedAtMeta));
    } else if (isInserting) {
      context.missing(_grantedAtMeta);
    }
    if (data.containsKey('grant_expires_at')) {
      context.handle(
          _grantExpiresAtMeta,
          grantExpiresAt.isAcceptableOrUnknown(
              data['grant_expires_at']!, _grantExpiresAtMeta));
    } else if (isInserting) {
      context.missing(_grantExpiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  DeviceSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceSessionRow(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      staffId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}staff_id'])!,
      staffName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}staff_name'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id'])!,
      grantedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}granted_at'])!,
      grantExpiresAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}grant_expires_at'])!,
    );
  }

  @override
  $DeviceSessionsTable createAlias(String alias) {
    return $DeviceSessionsTable(attachedDatabase, alias);
  }
}

class DeviceSessionRow extends DataClass
    implements Insertable<DeviceSessionRow> {
  final String deviceId;
  final String staffId;
  final String staffName;
  final String locationId;
  final DateTime grantedAt;
  final DateTime grantExpiresAt;
  const DeviceSessionRow(
      {required this.deviceId,
      required this.staffId,
      required this.staffName,
      required this.locationId,
      required this.grantedAt,
      required this.grantExpiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['staff_id'] = Variable<String>(staffId);
    map['staff_name'] = Variable<String>(staffName);
    map['location_id'] = Variable<String>(locationId);
    map['granted_at'] = Variable<DateTime>(grantedAt);
    map['grant_expires_at'] = Variable<DateTime>(grantExpiresAt);
    return map;
  }

  DeviceSessionsCompanion toCompanion(bool nullToAbsent) {
    return DeviceSessionsCompanion(
      deviceId: Value(deviceId),
      staffId: Value(staffId),
      staffName: Value(staffName),
      locationId: Value(locationId),
      grantedAt: Value(grantedAt),
      grantExpiresAt: Value(grantExpiresAt),
    );
  }

  factory DeviceSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceSessionRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      staffId: serializer.fromJson<String>(json['staffId']),
      staffName: serializer.fromJson<String>(json['staffName']),
      locationId: serializer.fromJson<String>(json['locationId']),
      grantedAt: serializer.fromJson<DateTime>(json['grantedAt']),
      grantExpiresAt: serializer.fromJson<DateTime>(json['grantExpiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'staffId': serializer.toJson<String>(staffId),
      'staffName': serializer.toJson<String>(staffName),
      'locationId': serializer.toJson<String>(locationId),
      'grantedAt': serializer.toJson<DateTime>(grantedAt),
      'grantExpiresAt': serializer.toJson<DateTime>(grantExpiresAt),
    };
  }

  DeviceSessionRow copyWith(
          {String? deviceId,
          String? staffId,
          String? staffName,
          String? locationId,
          DateTime? grantedAt,
          DateTime? grantExpiresAt}) =>
      DeviceSessionRow(
        deviceId: deviceId ?? this.deviceId,
        staffId: staffId ?? this.staffId,
        staffName: staffName ?? this.staffName,
        locationId: locationId ?? this.locationId,
        grantedAt: grantedAt ?? this.grantedAt,
        grantExpiresAt: grantExpiresAt ?? this.grantExpiresAt,
      );
  DeviceSessionRow copyWithCompanion(DeviceSessionsCompanion data) {
    return DeviceSessionRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      staffName: data.staffName.present ? data.staffName.value : this.staffName,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      grantedAt: data.grantedAt.present ? data.grantedAt.value : this.grantedAt,
      grantExpiresAt: data.grantExpiresAt.present
          ? data.grantExpiresAt.value
          : this.grantExpiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSessionRow(')
          ..write('deviceId: $deviceId, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('locationId: $locationId, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('grantExpiresAt: $grantExpiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      deviceId, staffId, staffName, locationId, grantedAt, grantExpiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSessionRow &&
          other.deviceId == this.deviceId &&
          other.staffId == this.staffId &&
          other.staffName == this.staffName &&
          other.locationId == this.locationId &&
          other.grantedAt == this.grantedAt &&
          other.grantExpiresAt == this.grantExpiresAt);
}

class DeviceSessionsCompanion extends UpdateCompanion<DeviceSessionRow> {
  final Value<String> deviceId;
  final Value<String> staffId;
  final Value<String> staffName;
  final Value<String> locationId;
  final Value<DateTime> grantedAt;
  final Value<DateTime> grantExpiresAt;
  final Value<int> rowid;
  const DeviceSessionsCompanion({
    this.deviceId = const Value.absent(),
    this.staffId = const Value.absent(),
    this.staffName = const Value.absent(),
    this.locationId = const Value.absent(),
    this.grantedAt = const Value.absent(),
    this.grantExpiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceSessionsCompanion.insert({
    required String deviceId,
    required String staffId,
    required String staffName,
    required String locationId,
    required DateTime grantedAt,
    required DateTime grantExpiresAt,
    this.rowid = const Value.absent(),
  })  : deviceId = Value(deviceId),
        staffId = Value(staffId),
        staffName = Value(staffName),
        locationId = Value(locationId),
        grantedAt = Value(grantedAt),
        grantExpiresAt = Value(grantExpiresAt);
  static Insertable<DeviceSessionRow> custom({
    Expression<String>? deviceId,
    Expression<String>? staffId,
    Expression<String>? staffName,
    Expression<String>? locationId,
    Expression<DateTime>? grantedAt,
    Expression<DateTime>? grantExpiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (staffId != null) 'staff_id': staffId,
      if (staffName != null) 'staff_name': staffName,
      if (locationId != null) 'location_id': locationId,
      if (grantedAt != null) 'granted_at': grantedAt,
      if (grantExpiresAt != null) 'grant_expires_at': grantExpiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceSessionsCompanion copyWith(
      {Value<String>? deviceId,
      Value<String>? staffId,
      Value<String>? staffName,
      Value<String>? locationId,
      Value<DateTime>? grantedAt,
      Value<DateTime>? grantExpiresAt,
      Value<int>? rowid}) {
    return DeviceSessionsCompanion(
      deviceId: deviceId ?? this.deviceId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      locationId: locationId ?? this.locationId,
      grantedAt: grantedAt ?? this.grantedAt,
      grantExpiresAt: grantExpiresAt ?? this.grantExpiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (staffName.present) {
      map['staff_name'] = Variable<String>(staffName.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (grantedAt.present) {
      map['granted_at'] = Variable<DateTime>(grantedAt.value);
    }
    if (grantExpiresAt.present) {
      map['grant_expires_at'] = Variable<DateTime>(grantExpiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSessionsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('locationId: $locationId, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('grantExpiresAt: $grantExpiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestaurantTablesTable extends RestaurantTables
    with TableInfo<$RestaurantTablesTable, RestaurantTableRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestaurantTablesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seatsMeta = const VerificationMeta('seats');
  @override
  late final GeneratedColumn<int> seats = GeneratedColumn<int>(
      'seats', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _zoneMeta = const VerificationMeta('zone');
  @override
  late final GeneratedColumn<String> zone = GeneratedColumn<String>(
      'zone', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _guestCountMeta =
      const VerificationMeta('guestCount');
  @override
  late final GeneratedColumn<int> guestCount = GeneratedColumn<int>(
      'guest_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _elapsedMinutesMeta =
      const VerificationMeta('elapsedMinutes');
  @override
  late final GeneratedColumn<int> elapsedMinutes = GeneratedColumn<int>(
      'elapsed_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _orderTotalMinorMeta =
      const VerificationMeta('orderTotalMinor');
  @override
  late final GeneratedColumn<int> orderTotalMinor = GeneratedColumn<int>(
      'order_total_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reservedByNameMeta =
      const VerificationMeta('reservedByName');
  @override
  late final GeneratedColumn<String> reservedByName = GeneratedColumn<String>(
      'reserved_by_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reservedAtMeta =
      const VerificationMeta('reservedAt');
  @override
  late final GeneratedColumn<DateTime> reservedAt = GeneratedColumn<DateTime>(
      'reserved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _floorMeta = const VerificationMeta('floor');
  @override
  late final GeneratedColumn<String> floor = GeneratedColumn<String>(
      'floor', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Ground Floor'));
  static const VerificationMeta _shapeMeta = const VerificationMeta('shape');
  @override
  late final GeneratedColumn<String> shape = GeneratedColumn<String>(
      'shape', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('square'));
  static const VerificationMeta _serverNameMeta =
      const VerificationMeta('serverName');
  @override
  late final GeneratedColumn<String> serverName = GeneratedColumn<String>(
      'server_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _paymentPendingMeta =
      const VerificationMeta('paymentPending');
  @override
  late final GeneratedColumn<bool> paymentPending = GeneratedColumn<bool>(
      'payment_pending', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("payment_pending" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _currentOrderIdMeta =
      const VerificationMeta('currentOrderId');
  @override
  late final GeneratedColumn<String> currentOrderId = GeneratedColumn<String>(
      'current_order_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seatedAtMeta =
      const VerificationMeta('seatedAt');
  @override
  late final GeneratedColumn<DateTime> seatedAt = GeneratedColumn<DateTime>(
      'seated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastCleanedAtMeta =
      const VerificationMeta('lastCleanedAt');
  @override
  late final GeneratedColumn<DateTime> lastCleanedAt =
      GeneratedColumn<DateTime>('last_cleaned_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        label,
        seats,
        zone,
        status,
        guestCount,
        elapsedMinutes,
        orderTotalMinor,
        reservedByName,
        reservedAt,
        createdAt,
        floor,
        shape,
        serverName,
        paymentPending,
        currentOrderId,
        seatedAt,
        lastCleanedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restaurant_tables';
  @override
  VerificationContext validateIntegrity(Insertable<RestaurantTableRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('seats')) {
      context.handle(
          _seatsMeta, seats.isAcceptableOrUnknown(data['seats']!, _seatsMeta));
    } else if (isInserting) {
      context.missing(_seatsMeta);
    }
    if (data.containsKey('zone')) {
      context.handle(
          _zoneMeta, zone.isAcceptableOrUnknown(data['zone']!, _zoneMeta));
    } else if (isInserting) {
      context.missing(_zoneMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('guest_count')) {
      context.handle(
          _guestCountMeta,
          guestCount.isAcceptableOrUnknown(
              data['guest_count']!, _guestCountMeta));
    }
    if (data.containsKey('elapsed_minutes')) {
      context.handle(
          _elapsedMinutesMeta,
          elapsedMinutes.isAcceptableOrUnknown(
              data['elapsed_minutes']!, _elapsedMinutesMeta));
    }
    if (data.containsKey('order_total_minor')) {
      context.handle(
          _orderTotalMinorMeta,
          orderTotalMinor.isAcceptableOrUnknown(
              data['order_total_minor']!, _orderTotalMinorMeta));
    }
    if (data.containsKey('reserved_by_name')) {
      context.handle(
          _reservedByNameMeta,
          reservedByName.isAcceptableOrUnknown(
              data['reserved_by_name']!, _reservedByNameMeta));
    }
    if (data.containsKey('reserved_at')) {
      context.handle(
          _reservedAtMeta,
          reservedAt.isAcceptableOrUnknown(
              data['reserved_at']!, _reservedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('floor')) {
      context.handle(
          _floorMeta, floor.isAcceptableOrUnknown(data['floor']!, _floorMeta));
    }
    if (data.containsKey('shape')) {
      context.handle(
          _shapeMeta, shape.isAcceptableOrUnknown(data['shape']!, _shapeMeta));
    }
    if (data.containsKey('server_name')) {
      context.handle(
          _serverNameMeta,
          serverName.isAcceptableOrUnknown(
              data['server_name']!, _serverNameMeta));
    }
    if (data.containsKey('payment_pending')) {
      context.handle(
          _paymentPendingMeta,
          paymentPending.isAcceptableOrUnknown(
              data['payment_pending']!, _paymentPendingMeta));
    }
    if (data.containsKey('current_order_id')) {
      context.handle(
          _currentOrderIdMeta,
          currentOrderId.isAcceptableOrUnknown(
              data['current_order_id']!, _currentOrderIdMeta));
    }
    if (data.containsKey('seated_at')) {
      context.handle(_seatedAtMeta,
          seatedAt.isAcceptableOrUnknown(data['seated_at']!, _seatedAtMeta));
    }
    if (data.containsKey('last_cleaned_at')) {
      context.handle(
          _lastCleanedAtMeta,
          lastCleanedAt.isAcceptableOrUnknown(
              data['last_cleaned_at']!, _lastCleanedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestaurantTableRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestaurantTableRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      seats: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seats'])!,
      zone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}zone'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      guestCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}guest_count']),
      elapsedMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}elapsed_minutes']),
      orderTotalMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_total_minor']),
      reservedByName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reserved_by_name']),
      reservedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reserved_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      floor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}floor'])!,
      shape: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shape'])!,
      serverName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_name'])!,
      paymentPending: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}payment_pending'])!,
      currentOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}current_order_id']),
      seatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}seated_at']),
      lastCleanedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_cleaned_at']),
    );
  }

  @override
  $RestaurantTablesTable createAlias(String alias) {
    return $RestaurantTablesTable(attachedDatabase, alias);
  }
}

class RestaurantTableRow extends DataClass
    implements Insertable<RestaurantTableRow> {
  final String id;
  final String label;
  final int seats;
  final String zone;
  final String status;
  final int? guestCount;
  final int? elapsedMinutes;
  final int? orderTotalMinor;
  final String? reservedByName;
  final DateTime? reservedAt;
  final DateTime createdAt;
  final String floor;
  final String shape;
  final String serverName;
  final bool paymentPending;
  final String? currentOrderId;
  final DateTime? seatedAt;
  final DateTime? lastCleanedAt;
  const RestaurantTableRow(
      {required this.id,
      required this.label,
      required this.seats,
      required this.zone,
      required this.status,
      this.guestCount,
      this.elapsedMinutes,
      this.orderTotalMinor,
      this.reservedByName,
      this.reservedAt,
      required this.createdAt,
      required this.floor,
      required this.shape,
      required this.serverName,
      required this.paymentPending,
      this.currentOrderId,
      this.seatedAt,
      this.lastCleanedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['seats'] = Variable<int>(seats);
    map['zone'] = Variable<String>(zone);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || guestCount != null) {
      map['guest_count'] = Variable<int>(guestCount);
    }
    if (!nullToAbsent || elapsedMinutes != null) {
      map['elapsed_minutes'] = Variable<int>(elapsedMinutes);
    }
    if (!nullToAbsent || orderTotalMinor != null) {
      map['order_total_minor'] = Variable<int>(orderTotalMinor);
    }
    if (!nullToAbsent || reservedByName != null) {
      map['reserved_by_name'] = Variable<String>(reservedByName);
    }
    if (!nullToAbsent || reservedAt != null) {
      map['reserved_at'] = Variable<DateTime>(reservedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['floor'] = Variable<String>(floor);
    map['shape'] = Variable<String>(shape);
    map['server_name'] = Variable<String>(serverName);
    map['payment_pending'] = Variable<bool>(paymentPending);
    if (!nullToAbsent || currentOrderId != null) {
      map['current_order_id'] = Variable<String>(currentOrderId);
    }
    if (!nullToAbsent || seatedAt != null) {
      map['seated_at'] = Variable<DateTime>(seatedAt);
    }
    if (!nullToAbsent || lastCleanedAt != null) {
      map['last_cleaned_at'] = Variable<DateTime>(lastCleanedAt);
    }
    return map;
  }

  RestaurantTablesCompanion toCompanion(bool nullToAbsent) {
    return RestaurantTablesCompanion(
      id: Value(id),
      label: Value(label),
      seats: Value(seats),
      zone: Value(zone),
      status: Value(status),
      guestCount: guestCount == null && nullToAbsent
          ? const Value.absent()
          : Value(guestCount),
      elapsedMinutes: elapsedMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedMinutes),
      orderTotalMinor: orderTotalMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(orderTotalMinor),
      reservedByName: reservedByName == null && nullToAbsent
          ? const Value.absent()
          : Value(reservedByName),
      reservedAt: reservedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reservedAt),
      createdAt: Value(createdAt),
      floor: Value(floor),
      shape: Value(shape),
      serverName: Value(serverName),
      paymentPending: Value(paymentPending),
      currentOrderId: currentOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentOrderId),
      seatedAt: seatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(seatedAt),
      lastCleanedAt: lastCleanedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCleanedAt),
    );
  }

  factory RestaurantTableRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestaurantTableRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      seats: serializer.fromJson<int>(json['seats']),
      zone: serializer.fromJson<String>(json['zone']),
      status: serializer.fromJson<String>(json['status']),
      guestCount: serializer.fromJson<int?>(json['guestCount']),
      elapsedMinutes: serializer.fromJson<int?>(json['elapsedMinutes']),
      orderTotalMinor: serializer.fromJson<int?>(json['orderTotalMinor']),
      reservedByName: serializer.fromJson<String?>(json['reservedByName']),
      reservedAt: serializer.fromJson<DateTime?>(json['reservedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      floor: serializer.fromJson<String>(json['floor']),
      shape: serializer.fromJson<String>(json['shape']),
      serverName: serializer.fromJson<String>(json['serverName']),
      paymentPending: serializer.fromJson<bool>(json['paymentPending']),
      currentOrderId: serializer.fromJson<String?>(json['currentOrderId']),
      seatedAt: serializer.fromJson<DateTime?>(json['seatedAt']),
      lastCleanedAt: serializer.fromJson<DateTime?>(json['lastCleanedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'seats': serializer.toJson<int>(seats),
      'zone': serializer.toJson<String>(zone),
      'status': serializer.toJson<String>(status),
      'guestCount': serializer.toJson<int?>(guestCount),
      'elapsedMinutes': serializer.toJson<int?>(elapsedMinutes),
      'orderTotalMinor': serializer.toJson<int?>(orderTotalMinor),
      'reservedByName': serializer.toJson<String?>(reservedByName),
      'reservedAt': serializer.toJson<DateTime?>(reservedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'floor': serializer.toJson<String>(floor),
      'shape': serializer.toJson<String>(shape),
      'serverName': serializer.toJson<String>(serverName),
      'paymentPending': serializer.toJson<bool>(paymentPending),
      'currentOrderId': serializer.toJson<String?>(currentOrderId),
      'seatedAt': serializer.toJson<DateTime?>(seatedAt),
      'lastCleanedAt': serializer.toJson<DateTime?>(lastCleanedAt),
    };
  }

  RestaurantTableRow copyWith(
          {String? id,
          String? label,
          int? seats,
          String? zone,
          String? status,
          Value<int?> guestCount = const Value.absent(),
          Value<int?> elapsedMinutes = const Value.absent(),
          Value<int?> orderTotalMinor = const Value.absent(),
          Value<String?> reservedByName = const Value.absent(),
          Value<DateTime?> reservedAt = const Value.absent(),
          DateTime? createdAt,
          String? floor,
          String? shape,
          String? serverName,
          bool? paymentPending,
          Value<String?> currentOrderId = const Value.absent(),
          Value<DateTime?> seatedAt = const Value.absent(),
          Value<DateTime?> lastCleanedAt = const Value.absent()}) =>
      RestaurantTableRow(
        id: id ?? this.id,
        label: label ?? this.label,
        seats: seats ?? this.seats,
        zone: zone ?? this.zone,
        status: status ?? this.status,
        guestCount: guestCount.present ? guestCount.value : this.guestCount,
        elapsedMinutes:
            elapsedMinutes.present ? elapsedMinutes.value : this.elapsedMinutes,
        orderTotalMinor: orderTotalMinor.present
            ? orderTotalMinor.value
            : this.orderTotalMinor,
        reservedByName:
            reservedByName.present ? reservedByName.value : this.reservedByName,
        reservedAt: reservedAt.present ? reservedAt.value : this.reservedAt,
        createdAt: createdAt ?? this.createdAt,
        floor: floor ?? this.floor,
        shape: shape ?? this.shape,
        serverName: serverName ?? this.serverName,
        paymentPending: paymentPending ?? this.paymentPending,
        currentOrderId:
            currentOrderId.present ? currentOrderId.value : this.currentOrderId,
        seatedAt: seatedAt.present ? seatedAt.value : this.seatedAt,
        lastCleanedAt:
            lastCleanedAt.present ? lastCleanedAt.value : this.lastCleanedAt,
      );
  RestaurantTableRow copyWithCompanion(RestaurantTablesCompanion data) {
    return RestaurantTableRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      seats: data.seats.present ? data.seats.value : this.seats,
      zone: data.zone.present ? data.zone.value : this.zone,
      status: data.status.present ? data.status.value : this.status,
      guestCount:
          data.guestCount.present ? data.guestCount.value : this.guestCount,
      elapsedMinutes: data.elapsedMinutes.present
          ? data.elapsedMinutes.value
          : this.elapsedMinutes,
      orderTotalMinor: data.orderTotalMinor.present
          ? data.orderTotalMinor.value
          : this.orderTotalMinor,
      reservedByName: data.reservedByName.present
          ? data.reservedByName.value
          : this.reservedByName,
      reservedAt:
          data.reservedAt.present ? data.reservedAt.value : this.reservedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      floor: data.floor.present ? data.floor.value : this.floor,
      shape: data.shape.present ? data.shape.value : this.shape,
      serverName:
          data.serverName.present ? data.serverName.value : this.serverName,
      paymentPending: data.paymentPending.present
          ? data.paymentPending.value
          : this.paymentPending,
      currentOrderId: data.currentOrderId.present
          ? data.currentOrderId.value
          : this.currentOrderId,
      seatedAt: data.seatedAt.present ? data.seatedAt.value : this.seatedAt,
      lastCleanedAt: data.lastCleanedAt.present
          ? data.lastCleanedAt.value
          : this.lastCleanedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantTableRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('seats: $seats, ')
          ..write('zone: $zone, ')
          ..write('status: $status, ')
          ..write('guestCount: $guestCount, ')
          ..write('elapsedMinutes: $elapsedMinutes, ')
          ..write('orderTotalMinor: $orderTotalMinor, ')
          ..write('reservedByName: $reservedByName, ')
          ..write('reservedAt: $reservedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('floor: $floor, ')
          ..write('shape: $shape, ')
          ..write('serverName: $serverName, ')
          ..write('paymentPending: $paymentPending, ')
          ..write('currentOrderId: $currentOrderId, ')
          ..write('seatedAt: $seatedAt, ')
          ..write('lastCleanedAt: $lastCleanedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      label,
      seats,
      zone,
      status,
      guestCount,
      elapsedMinutes,
      orderTotalMinor,
      reservedByName,
      reservedAt,
      createdAt,
      floor,
      shape,
      serverName,
      paymentPending,
      currentOrderId,
      seatedAt,
      lastCleanedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestaurantTableRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.seats == this.seats &&
          other.zone == this.zone &&
          other.status == this.status &&
          other.guestCount == this.guestCount &&
          other.elapsedMinutes == this.elapsedMinutes &&
          other.orderTotalMinor == this.orderTotalMinor &&
          other.reservedByName == this.reservedByName &&
          other.reservedAt == this.reservedAt &&
          other.createdAt == this.createdAt &&
          other.floor == this.floor &&
          other.shape == this.shape &&
          other.serverName == this.serverName &&
          other.paymentPending == this.paymentPending &&
          other.currentOrderId == this.currentOrderId &&
          other.seatedAt == this.seatedAt &&
          other.lastCleanedAt == this.lastCleanedAt);
}

class RestaurantTablesCompanion extends UpdateCompanion<RestaurantTableRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<int> seats;
  final Value<String> zone;
  final Value<String> status;
  final Value<int?> guestCount;
  final Value<int?> elapsedMinutes;
  final Value<int?> orderTotalMinor;
  final Value<String?> reservedByName;
  final Value<DateTime?> reservedAt;
  final Value<DateTime> createdAt;
  final Value<String> floor;
  final Value<String> shape;
  final Value<String> serverName;
  final Value<bool> paymentPending;
  final Value<String?> currentOrderId;
  final Value<DateTime?> seatedAt;
  final Value<DateTime?> lastCleanedAt;
  final Value<int> rowid;
  const RestaurantTablesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.seats = const Value.absent(),
    this.zone = const Value.absent(),
    this.status = const Value.absent(),
    this.guestCount = const Value.absent(),
    this.elapsedMinutes = const Value.absent(),
    this.orderTotalMinor = const Value.absent(),
    this.reservedByName = const Value.absent(),
    this.reservedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.floor = const Value.absent(),
    this.shape = const Value.absent(),
    this.serverName = const Value.absent(),
    this.paymentPending = const Value.absent(),
    this.currentOrderId = const Value.absent(),
    this.seatedAt = const Value.absent(),
    this.lastCleanedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestaurantTablesCompanion.insert({
    required String id,
    required String label,
    required int seats,
    required String zone,
    required String status,
    this.guestCount = const Value.absent(),
    this.elapsedMinutes = const Value.absent(),
    this.orderTotalMinor = const Value.absent(),
    this.reservedByName = const Value.absent(),
    this.reservedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.floor = const Value.absent(),
    this.shape = const Value.absent(),
    this.serverName = const Value.absent(),
    this.paymentPending = const Value.absent(),
    this.currentOrderId = const Value.absent(),
    this.seatedAt = const Value.absent(),
    this.lastCleanedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        label = Value(label),
        seats = Value(seats),
        zone = Value(zone),
        status = Value(status);
  static Insertable<RestaurantTableRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<int>? seats,
    Expression<String>? zone,
    Expression<String>? status,
    Expression<int>? guestCount,
    Expression<int>? elapsedMinutes,
    Expression<int>? orderTotalMinor,
    Expression<String>? reservedByName,
    Expression<DateTime>? reservedAt,
    Expression<DateTime>? createdAt,
    Expression<String>? floor,
    Expression<String>? shape,
    Expression<String>? serverName,
    Expression<bool>? paymentPending,
    Expression<String>? currentOrderId,
    Expression<DateTime>? seatedAt,
    Expression<DateTime>? lastCleanedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (seats != null) 'seats': seats,
      if (zone != null) 'zone': zone,
      if (status != null) 'status': status,
      if (guestCount != null) 'guest_count': guestCount,
      if (elapsedMinutes != null) 'elapsed_minutes': elapsedMinutes,
      if (orderTotalMinor != null) 'order_total_minor': orderTotalMinor,
      if (reservedByName != null) 'reserved_by_name': reservedByName,
      if (reservedAt != null) 'reserved_at': reservedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (floor != null) 'floor': floor,
      if (shape != null) 'shape': shape,
      if (serverName != null) 'server_name': serverName,
      if (paymentPending != null) 'payment_pending': paymentPending,
      if (currentOrderId != null) 'current_order_id': currentOrderId,
      if (seatedAt != null) 'seated_at': seatedAt,
      if (lastCleanedAt != null) 'last_cleaned_at': lastCleanedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestaurantTablesCompanion copyWith(
      {Value<String>? id,
      Value<String>? label,
      Value<int>? seats,
      Value<String>? zone,
      Value<String>? status,
      Value<int?>? guestCount,
      Value<int?>? elapsedMinutes,
      Value<int?>? orderTotalMinor,
      Value<String?>? reservedByName,
      Value<DateTime?>? reservedAt,
      Value<DateTime>? createdAt,
      Value<String>? floor,
      Value<String>? shape,
      Value<String>? serverName,
      Value<bool>? paymentPending,
      Value<String?>? currentOrderId,
      Value<DateTime?>? seatedAt,
      Value<DateTime?>? lastCleanedAt,
      Value<int>? rowid}) {
    return RestaurantTablesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      seats: seats ?? this.seats,
      zone: zone ?? this.zone,
      status: status ?? this.status,
      guestCount: guestCount ?? this.guestCount,
      elapsedMinutes: elapsedMinutes ?? this.elapsedMinutes,
      orderTotalMinor: orderTotalMinor ?? this.orderTotalMinor,
      reservedByName: reservedByName ?? this.reservedByName,
      reservedAt: reservedAt ?? this.reservedAt,
      createdAt: createdAt ?? this.createdAt,
      floor: floor ?? this.floor,
      shape: shape ?? this.shape,
      serverName: serverName ?? this.serverName,
      paymentPending: paymentPending ?? this.paymentPending,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      seatedAt: seatedAt ?? this.seatedAt,
      lastCleanedAt: lastCleanedAt ?? this.lastCleanedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (seats.present) {
      map['seats'] = Variable<int>(seats.value);
    }
    if (zone.present) {
      map['zone'] = Variable<String>(zone.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (guestCount.present) {
      map['guest_count'] = Variable<int>(guestCount.value);
    }
    if (elapsedMinutes.present) {
      map['elapsed_minutes'] = Variable<int>(elapsedMinutes.value);
    }
    if (orderTotalMinor.present) {
      map['order_total_minor'] = Variable<int>(orderTotalMinor.value);
    }
    if (reservedByName.present) {
      map['reserved_by_name'] = Variable<String>(reservedByName.value);
    }
    if (reservedAt.present) {
      map['reserved_at'] = Variable<DateTime>(reservedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (floor.present) {
      map['floor'] = Variable<String>(floor.value);
    }
    if (shape.present) {
      map['shape'] = Variable<String>(shape.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (paymentPending.present) {
      map['payment_pending'] = Variable<bool>(paymentPending.value);
    }
    if (currentOrderId.present) {
      map['current_order_id'] = Variable<String>(currentOrderId.value);
    }
    if (seatedAt.present) {
      map['seated_at'] = Variable<DateTime>(seatedAt.value);
    }
    if (lastCleanedAt.present) {
      map['last_cleaned_at'] = Variable<DateTime>(lastCleanedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantTablesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('seats: $seats, ')
          ..write('zone: $zone, ')
          ..write('status: $status, ')
          ..write('guestCount: $guestCount, ')
          ..write('elapsedMinutes: $elapsedMinutes, ')
          ..write('orderTotalMinor: $orderTotalMinor, ')
          ..write('reservedByName: $reservedByName, ')
          ..write('reservedAt: $reservedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('floor: $floor, ')
          ..write('shape: $shape, ')
          ..write('serverName: $serverName, ')
          ..write('paymentPending: $paymentPending, ')
          ..write('currentOrderId: $currentOrderId, ')
          ..write('seatedAt: $seatedAt, ')
          ..write('lastCleanedAt: $lastCleanedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AllOrdersTableTable extends AllOrdersTable
    with TableInfo<$AllOrdersTableTable, AllOrderEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllOrdersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tableOrCustomerMeta =
      const VerificationMeta('tableOrCustomer');
  @override
  late final GeneratedColumn<String> tableOrCustomer = GeneratedColumn<String>(
      'table_or_customer', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemsLabelMeta =
      const VerificationMeta('itemsLabel');
  @override
  late final GeneratedColumn<String> itemsLabel = GeneratedColumn<String>(
      'items_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        orderId,
        type,
        source,
        tableOrCustomer,
        itemsLabel,
        amountMinor,
        status,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'all_orders_table';
  @override
  VerificationContext validateIntegrity(Insertable<AllOrderEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('table_or_customer')) {
      context.handle(
          _tableOrCustomerMeta,
          tableOrCustomer.isAcceptableOrUnknown(
              data['table_or_customer']!, _tableOrCustomerMeta));
    } else if (isInserting) {
      context.missing(_tableOrCustomerMeta);
    }
    if (data.containsKey('items_label')) {
      context.handle(
          _itemsLabelMeta,
          itemsLabel.isAcceptableOrUnknown(
              data['items_label']!, _itemsLabelMeta));
    } else if (isInserting) {
      context.missing(_itemsLabelMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {orderId};
  @override
  AllOrderEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllOrderEntity(
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      tableOrCustomer: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}table_or_customer'])!,
      itemsLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}items_label'])!,
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AllOrdersTableTable createAlias(String alias) {
    return $AllOrdersTableTable(attachedDatabase, alias);
  }
}

class AllOrderEntity extends DataClass implements Insertable<AllOrderEntity> {
  final String orderId;
  final String type;
  final String source;
  final String tableOrCustomer;
  final String itemsLabel;
  final int amountMinor;
  final String status;
  final DateTime createdAt;
  const AllOrderEntity(
      {required this.orderId,
      required this.type,
      required this.source,
      required this.tableOrCustomer,
      required this.itemsLabel,
      required this.amountMinor,
      required this.status,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['order_id'] = Variable<String>(orderId);
    map['type'] = Variable<String>(type);
    map['source'] = Variable<String>(source);
    map['table_or_customer'] = Variable<String>(tableOrCustomer);
    map['items_label'] = Variable<String>(itemsLabel);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AllOrdersTableCompanion toCompanion(bool nullToAbsent) {
    return AllOrdersTableCompanion(
      orderId: Value(orderId),
      type: Value(type),
      source: Value(source),
      tableOrCustomer: Value(tableOrCustomer),
      itemsLabel: Value(itemsLabel),
      amountMinor: Value(amountMinor),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory AllOrderEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllOrderEntity(
      orderId: serializer.fromJson<String>(json['orderId']),
      type: serializer.fromJson<String>(json['type']),
      source: serializer.fromJson<String>(json['source']),
      tableOrCustomer: serializer.fromJson<String>(json['tableOrCustomer']),
      itemsLabel: serializer.fromJson<String>(json['itemsLabel']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'orderId': serializer.toJson<String>(orderId),
      'type': serializer.toJson<String>(type),
      'source': serializer.toJson<String>(source),
      'tableOrCustomer': serializer.toJson<String>(tableOrCustomer),
      'itemsLabel': serializer.toJson<String>(itemsLabel),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AllOrderEntity copyWith(
          {String? orderId,
          String? type,
          String? source,
          String? tableOrCustomer,
          String? itemsLabel,
          int? amountMinor,
          String? status,
          DateTime? createdAt}) =>
      AllOrderEntity(
        orderId: orderId ?? this.orderId,
        type: type ?? this.type,
        source: source ?? this.source,
        tableOrCustomer: tableOrCustomer ?? this.tableOrCustomer,
        itemsLabel: itemsLabel ?? this.itemsLabel,
        amountMinor: amountMinor ?? this.amountMinor,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  AllOrderEntity copyWithCompanion(AllOrdersTableCompanion data) {
    return AllOrderEntity(
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      type: data.type.present ? data.type.value : this.type,
      source: data.source.present ? data.source.value : this.source,
      tableOrCustomer: data.tableOrCustomer.present
          ? data.tableOrCustomer.value
          : this.tableOrCustomer,
      itemsLabel:
          data.itemsLabel.present ? data.itemsLabel.value : this.itemsLabel,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllOrderEntity(')
          ..write('orderId: $orderId, ')
          ..write('type: $type, ')
          ..write('source: $source, ')
          ..write('tableOrCustomer: $tableOrCustomer, ')
          ..write('itemsLabel: $itemsLabel, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(orderId, type, source, tableOrCustomer,
      itemsLabel, amountMinor, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllOrderEntity &&
          other.orderId == this.orderId &&
          other.type == this.type &&
          other.source == this.source &&
          other.tableOrCustomer == this.tableOrCustomer &&
          other.itemsLabel == this.itemsLabel &&
          other.amountMinor == this.amountMinor &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class AllOrdersTableCompanion extends UpdateCompanion<AllOrderEntity> {
  final Value<String> orderId;
  final Value<String> type;
  final Value<String> source;
  final Value<String> tableOrCustomer;
  final Value<String> itemsLabel;
  final Value<int> amountMinor;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AllOrdersTableCompanion({
    this.orderId = const Value.absent(),
    this.type = const Value.absent(),
    this.source = const Value.absent(),
    this.tableOrCustomer = const Value.absent(),
    this.itemsLabel = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AllOrdersTableCompanion.insert({
    required String orderId,
    required String type,
    required String source,
    required String tableOrCustomer,
    required String itemsLabel,
    required int amountMinor,
    required String status,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : orderId = Value(orderId),
        type = Value(type),
        source = Value(source),
        tableOrCustomer = Value(tableOrCustomer),
        itemsLabel = Value(itemsLabel),
        amountMinor = Value(amountMinor),
        status = Value(status);
  static Insertable<AllOrderEntity> custom({
    Expression<String>? orderId,
    Expression<String>? type,
    Expression<String>? source,
    Expression<String>? tableOrCustomer,
    Expression<String>? itemsLabel,
    Expression<int>? amountMinor,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (orderId != null) 'order_id': orderId,
      if (type != null) 'type': type,
      if (source != null) 'source': source,
      if (tableOrCustomer != null) 'table_or_customer': tableOrCustomer,
      if (itemsLabel != null) 'items_label': itemsLabel,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AllOrdersTableCompanion copyWith(
      {Value<String>? orderId,
      Value<String>? type,
      Value<String>? source,
      Value<String>? tableOrCustomer,
      Value<String>? itemsLabel,
      Value<int>? amountMinor,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AllOrdersTableCompanion(
      orderId: orderId ?? this.orderId,
      type: type ?? this.type,
      source: source ?? this.source,
      tableOrCustomer: tableOrCustomer ?? this.tableOrCustomer,
      itemsLabel: itemsLabel ?? this.itemsLabel,
      amountMinor: amountMinor ?? this.amountMinor,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (tableOrCustomer.present) {
      map['table_or_customer'] = Variable<String>(tableOrCustomer.value);
    }
    if (itemsLabel.present) {
      map['items_label'] = Variable<String>(itemsLabel.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllOrdersTableCompanion(')
          ..write('orderId: $orderId, ')
          ..write('type: $type, ')
          ..write('source: $source, ')
          ..write('tableOrCustomer: $tableOrCustomer, ')
          ..write('itemsLabel: $itemsLabel, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MenuCategoriesTableTable extends MenuCategoriesTable
    with TableInfo<$MenuCategoriesTableTable, MenuCategoryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenuCategoriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menu_categories_table';
  @override
  VerificationContext validateIntegrity(Insertable<MenuCategoryEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MenuCategoryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuCategoryEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MenuCategoriesTableTable createAlias(String alias) {
    return $MenuCategoriesTableTable(attachedDatabase, alias);
  }
}

class MenuCategoryEntity extends DataClass
    implements Insertable<MenuCategoryEntity> {
  final String id;
  final String name;
  final DateTime createdAt;
  const MenuCategoryEntity(
      {required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MenuCategoriesTableCompanion toCompanion(bool nullToAbsent) {
    return MenuCategoriesTableCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory MenuCategoryEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuCategoryEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MenuCategoryEntity copyWith(
          {String? id, String? name, DateTime? createdAt}) =>
      MenuCategoryEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  MenuCategoryEntity copyWithCompanion(MenuCategoriesTableCompanion data) {
    return MenuCategoryEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MenuCategoryEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuCategoryEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class MenuCategoriesTableCompanion extends UpdateCompanion<MenuCategoryEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MenuCategoriesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MenuCategoriesTableCompanion.insert({
    required String id,
    required String name,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<MenuCategoryEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MenuCategoriesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MenuCategoriesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenuCategoriesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MenuItemsTableTable extends MenuItemsTable
    with TableInfo<$MenuItemsTableTable, MenuItemEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenuItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMinorMeta =
      const VerificationMeta('priceMinor');
  @override
  late final GeneratedColumn<int> priceMinor = GeneratedColumn<int>(
      'price_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isVegMeta = const VerificationMeta('isVeg');
  @override
  late final GeneratedColumn<bool> isVeg = GeneratedColumn<bool>(
      'is_veg', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_veg" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isBestsellerMeta =
      const VerificationMeta('isBestseller');
  @override
  late final GeneratedColumn<bool> isBestseller = GeneratedColumn<bool>(
      'is_bestseller', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_bestseller" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _availableMeta =
      const VerificationMeta('available');
  @override
  late final GeneratedColumn<bool> available = GeneratedColumn<bool>(
      'available', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("available" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _unavailableReasonMeta =
      const VerificationMeta('unavailableReason');
  @override
  late final GeneratedColumn<String> unavailableReason =
      GeneratedColumn<String>('unavailable_reason', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _hsnMeta = const VerificationMeta('hsn');
  @override
  late final GeneratedColumn<String> hsn = GeneratedColumn<String>(
      'hsn', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _foodCostMinorMeta =
      const VerificationMeta('foodCostMinor');
  @override
  late final GeneratedColumn<int> foodCostMinor = GeneratedColumn<int>(
      'food_cost_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _channelsMeta =
      const VerificationMeta('channels');
  @override
  late final GeneratedColumn<String> channels = GeneratedColumn<String>(
      'channels', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('POS'));
  static const VerificationMeta _kitchenStationMeta =
      const VerificationMeta('kitchenStation');
  @override
  late final GeneratedColumn<String> kitchenStation = GeneratedColumn<String>(
      'kitchen_station', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _menuStatusMeta =
      const VerificationMeta('menuStatus');
  @override
  late final GeneratedColumn<String> menuStatus = GeneratedColumn<String>(
      'menu_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Active'));
  static const VerificationMeta _availabilityLabelMeta =
      const VerificationMeta('availabilityLabel');
  @override
  late final GeneratedColumn<String> availabilityLabel =
      GeneratedColumn<String>('availability_label', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('In Stock'));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _dietTypeMeta =
      const VerificationMeta('dietType');
  @override
  late final GeneratedColumn<String> dietType = GeneratedColumn<String>(
      'diet_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('veg'));
  static const VerificationMeta _detailsJsonMeta =
      const VerificationMeta('detailsJson');
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
      'details_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        categoryId,
        name,
        priceMinor,
        isVeg,
        isBestseller,
        available,
        unavailableReason,
        createdAt,
        sku,
        hsn,
        foodCostMinor,
        channels,
        kitchenStation,
        menuStatus,
        availabilityLabel,
        imageUrl,
        dietType,
        detailsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menu_items_table';
  @override
  VerificationContext validateIntegrity(Insertable<MenuItemEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price_minor')) {
      context.handle(
          _priceMinorMeta,
          priceMinor.isAcceptableOrUnknown(
              data['price_minor']!, _priceMinorMeta));
    } else if (isInserting) {
      context.missing(_priceMinorMeta);
    }
    if (data.containsKey('is_veg')) {
      context.handle(
          _isVegMeta, isVeg.isAcceptableOrUnknown(data['is_veg']!, _isVegMeta));
    }
    if (data.containsKey('is_bestseller')) {
      context.handle(
          _isBestsellerMeta,
          isBestseller.isAcceptableOrUnknown(
              data['is_bestseller']!, _isBestsellerMeta));
    }
    if (data.containsKey('available')) {
      context.handle(_availableMeta,
          available.isAcceptableOrUnknown(data['available']!, _availableMeta));
    }
    if (data.containsKey('unavailable_reason')) {
      context.handle(
          _unavailableReasonMeta,
          unavailableReason.isAcceptableOrUnknown(
              data['unavailable_reason']!, _unavailableReasonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    }
    if (data.containsKey('hsn')) {
      context.handle(
          _hsnMeta, hsn.isAcceptableOrUnknown(data['hsn']!, _hsnMeta));
    }
    if (data.containsKey('food_cost_minor')) {
      context.handle(
          _foodCostMinorMeta,
          foodCostMinor.isAcceptableOrUnknown(
              data['food_cost_minor']!, _foodCostMinorMeta));
    }
    if (data.containsKey('channels')) {
      context.handle(_channelsMeta,
          channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta));
    }
    if (data.containsKey('kitchen_station')) {
      context.handle(
          _kitchenStationMeta,
          kitchenStation.isAcceptableOrUnknown(
              data['kitchen_station']!, _kitchenStationMeta));
    }
    if (data.containsKey('menu_status')) {
      context.handle(
          _menuStatusMeta,
          menuStatus.isAcceptableOrUnknown(
              data['menu_status']!, _menuStatusMeta));
    }
    if (data.containsKey('availability_label')) {
      context.handle(
          _availabilityLabelMeta,
          availabilityLabel.isAcceptableOrUnknown(
              data['availability_label']!, _availabilityLabelMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('diet_type')) {
      context.handle(_dietTypeMeta,
          dietType.isAcceptableOrUnknown(data['diet_type']!, _dietTypeMeta));
    }
    if (data.containsKey('details_json')) {
      context.handle(
          _detailsJsonMeta,
          detailsJson.isAcceptableOrUnknown(
              data['details_json']!, _detailsJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MenuItemEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuItemEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      priceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_minor'])!,
      isVeg: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_veg'])!,
      isBestseller: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_bestseller'])!,
      available: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}available'])!,
      unavailableReason: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}unavailable_reason']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku'])!,
      hsn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hsn'])!,
      foodCostMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}food_cost_minor'])!,
      channels: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channels'])!,
      kitchenStation: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}kitchen_station'])!,
      menuStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}menu_status'])!,
      availabilityLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}availability_label'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url'])!,
      dietType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}diet_type'])!,
      detailsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}details_json'])!,
    );
  }

  @override
  $MenuItemsTableTable createAlias(String alias) {
    return $MenuItemsTableTable(attachedDatabase, alias);
  }
}

class MenuItemEntity extends DataClass implements Insertable<MenuItemEntity> {
  final String id;
  final String categoryId;
  final String name;
  final int priceMinor;
  final bool isVeg;
  final bool isBestseller;
  final bool available;
  final String? unavailableReason;
  final DateTime createdAt;
  final String sku;
  final String hsn;
  final int foodCostMinor;
  final String channels;
  final String kitchenStation;
  final String menuStatus;
  final String availabilityLabel;
  final String imageUrl;
  final String dietType;

  /// Remaining Add/Edit Item form fields (short name, barcode, prep time,
  /// tax, packaging, order types, …) as a JSON object.
  final String detailsJson;
  const MenuItemEntity(
      {required this.id,
      required this.categoryId,
      required this.name,
      required this.priceMinor,
      required this.isVeg,
      required this.isBestseller,
      required this.available,
      this.unavailableReason,
      required this.createdAt,
      required this.sku,
      required this.hsn,
      required this.foodCostMinor,
      required this.channels,
      required this.kitchenStation,
      required this.menuStatus,
      required this.availabilityLabel,
      required this.imageUrl,
      required this.dietType,
      required this.detailsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    map['price_minor'] = Variable<int>(priceMinor);
    map['is_veg'] = Variable<bool>(isVeg);
    map['is_bestseller'] = Variable<bool>(isBestseller);
    map['available'] = Variable<bool>(available);
    if (!nullToAbsent || unavailableReason != null) {
      map['unavailable_reason'] = Variable<String>(unavailableReason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sku'] = Variable<String>(sku);
    map['hsn'] = Variable<String>(hsn);
    map['food_cost_minor'] = Variable<int>(foodCostMinor);
    map['channels'] = Variable<String>(channels);
    map['kitchen_station'] = Variable<String>(kitchenStation);
    map['menu_status'] = Variable<String>(menuStatus);
    map['availability_label'] = Variable<String>(availabilityLabel);
    map['image_url'] = Variable<String>(imageUrl);
    map['diet_type'] = Variable<String>(dietType);
    map['details_json'] = Variable<String>(detailsJson);
    return map;
  }

  MenuItemsTableCompanion toCompanion(bool nullToAbsent) {
    return MenuItemsTableCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      name: Value(name),
      priceMinor: Value(priceMinor),
      isVeg: Value(isVeg),
      isBestseller: Value(isBestseller),
      available: Value(available),
      unavailableReason: unavailableReason == null && nullToAbsent
          ? const Value.absent()
          : Value(unavailableReason),
      createdAt: Value(createdAt),
      sku: Value(sku),
      hsn: Value(hsn),
      foodCostMinor: Value(foodCostMinor),
      channels: Value(channels),
      kitchenStation: Value(kitchenStation),
      menuStatus: Value(menuStatus),
      availabilityLabel: Value(availabilityLabel),
      imageUrl: Value(imageUrl),
      dietType: Value(dietType),
      detailsJson: Value(detailsJson),
    );
  }

  factory MenuItemEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuItemEntity(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      priceMinor: serializer.fromJson<int>(json['priceMinor']),
      isVeg: serializer.fromJson<bool>(json['isVeg']),
      isBestseller: serializer.fromJson<bool>(json['isBestseller']),
      available: serializer.fromJson<bool>(json['available']),
      unavailableReason:
          serializer.fromJson<String?>(json['unavailableReason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sku: serializer.fromJson<String>(json['sku']),
      hsn: serializer.fromJson<String>(json['hsn']),
      foodCostMinor: serializer.fromJson<int>(json['foodCostMinor']),
      channels: serializer.fromJson<String>(json['channels']),
      kitchenStation: serializer.fromJson<String>(json['kitchenStation']),
      menuStatus: serializer.fromJson<String>(json['menuStatus']),
      availabilityLabel: serializer.fromJson<String>(json['availabilityLabel']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
      dietType: serializer.fromJson<String>(json['dietType']),
      detailsJson: serializer.fromJson<String>(json['detailsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'priceMinor': serializer.toJson<int>(priceMinor),
      'isVeg': serializer.toJson<bool>(isVeg),
      'isBestseller': serializer.toJson<bool>(isBestseller),
      'available': serializer.toJson<bool>(available),
      'unavailableReason': serializer.toJson<String?>(unavailableReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sku': serializer.toJson<String>(sku),
      'hsn': serializer.toJson<String>(hsn),
      'foodCostMinor': serializer.toJson<int>(foodCostMinor),
      'channels': serializer.toJson<String>(channels),
      'kitchenStation': serializer.toJson<String>(kitchenStation),
      'menuStatus': serializer.toJson<String>(menuStatus),
      'availabilityLabel': serializer.toJson<String>(availabilityLabel),
      'imageUrl': serializer.toJson<String>(imageUrl),
      'dietType': serializer.toJson<String>(dietType),
      'detailsJson': serializer.toJson<String>(detailsJson),
    };
  }

  MenuItemEntity copyWith(
          {String? id,
          String? categoryId,
          String? name,
          int? priceMinor,
          bool? isVeg,
          bool? isBestseller,
          bool? available,
          Value<String?> unavailableReason = const Value.absent(),
          DateTime? createdAt,
          String? sku,
          String? hsn,
          int? foodCostMinor,
          String? channels,
          String? kitchenStation,
          String? menuStatus,
          String? availabilityLabel,
          String? imageUrl,
          String? dietType,
          String? detailsJson}) =>
      MenuItemEntity(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        priceMinor: priceMinor ?? this.priceMinor,
        isVeg: isVeg ?? this.isVeg,
        isBestseller: isBestseller ?? this.isBestseller,
        available: available ?? this.available,
        unavailableReason: unavailableReason.present
            ? unavailableReason.value
            : this.unavailableReason,
        createdAt: createdAt ?? this.createdAt,
        sku: sku ?? this.sku,
        hsn: hsn ?? this.hsn,
        foodCostMinor: foodCostMinor ?? this.foodCostMinor,
        channels: channels ?? this.channels,
        kitchenStation: kitchenStation ?? this.kitchenStation,
        menuStatus: menuStatus ?? this.menuStatus,
        availabilityLabel: availabilityLabel ?? this.availabilityLabel,
        imageUrl: imageUrl ?? this.imageUrl,
        dietType: dietType ?? this.dietType,
        detailsJson: detailsJson ?? this.detailsJson,
      );
  MenuItemEntity copyWithCompanion(MenuItemsTableCompanion data) {
    return MenuItemEntity(
      id: data.id.present ? data.id.value : this.id,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      priceMinor:
          data.priceMinor.present ? data.priceMinor.value : this.priceMinor,
      isVeg: data.isVeg.present ? data.isVeg.value : this.isVeg,
      isBestseller: data.isBestseller.present
          ? data.isBestseller.value
          : this.isBestseller,
      available: data.available.present ? data.available.value : this.available,
      unavailableReason: data.unavailableReason.present
          ? data.unavailableReason.value
          : this.unavailableReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sku: data.sku.present ? data.sku.value : this.sku,
      hsn: data.hsn.present ? data.hsn.value : this.hsn,
      foodCostMinor: data.foodCostMinor.present
          ? data.foodCostMinor.value
          : this.foodCostMinor,
      channels: data.channels.present ? data.channels.value : this.channels,
      kitchenStation: data.kitchenStation.present
          ? data.kitchenStation.value
          : this.kitchenStation,
      menuStatus:
          data.menuStatus.present ? data.menuStatus.value : this.menuStatus,
      availabilityLabel: data.availabilityLabel.present
          ? data.availabilityLabel.value
          : this.availabilityLabel,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      dietType: data.dietType.present ? data.dietType.value : this.dietType,
      detailsJson:
          data.detailsJson.present ? data.detailsJson.value : this.detailsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MenuItemEntity(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('isVeg: $isVeg, ')
          ..write('isBestseller: $isBestseller, ')
          ..write('available: $available, ')
          ..write('unavailableReason: $unavailableReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('sku: $sku, ')
          ..write('hsn: $hsn, ')
          ..write('foodCostMinor: $foodCostMinor, ')
          ..write('channels: $channels, ')
          ..write('kitchenStation: $kitchenStation, ')
          ..write('menuStatus: $menuStatus, ')
          ..write('availabilityLabel: $availabilityLabel, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('dietType: $dietType, ')
          ..write('detailsJson: $detailsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      categoryId,
      name,
      priceMinor,
      isVeg,
      isBestseller,
      available,
      unavailableReason,
      createdAt,
      sku,
      hsn,
      foodCostMinor,
      channels,
      kitchenStation,
      menuStatus,
      availabilityLabel,
      imageUrl,
      dietType,
      detailsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuItemEntity &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.priceMinor == this.priceMinor &&
          other.isVeg == this.isVeg &&
          other.isBestseller == this.isBestseller &&
          other.available == this.available &&
          other.unavailableReason == this.unavailableReason &&
          other.createdAt == this.createdAt &&
          other.sku == this.sku &&
          other.hsn == this.hsn &&
          other.foodCostMinor == this.foodCostMinor &&
          other.channels == this.channels &&
          other.kitchenStation == this.kitchenStation &&
          other.menuStatus == this.menuStatus &&
          other.availabilityLabel == this.availabilityLabel &&
          other.imageUrl == this.imageUrl &&
          other.dietType == this.dietType &&
          other.detailsJson == this.detailsJson);
}

class MenuItemsTableCompanion extends UpdateCompanion<MenuItemEntity> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<int> priceMinor;
  final Value<bool> isVeg;
  final Value<bool> isBestseller;
  final Value<bool> available;
  final Value<String?> unavailableReason;
  final Value<DateTime> createdAt;
  final Value<String> sku;
  final Value<String> hsn;
  final Value<int> foodCostMinor;
  final Value<String> channels;
  final Value<String> kitchenStation;
  final Value<String> menuStatus;
  final Value<String> availabilityLabel;
  final Value<String> imageUrl;
  final Value<String> dietType;
  final Value<String> detailsJson;
  final Value<int> rowid;
  const MenuItemsTableCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.priceMinor = const Value.absent(),
    this.isVeg = const Value.absent(),
    this.isBestseller = const Value.absent(),
    this.available = const Value.absent(),
    this.unavailableReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sku = const Value.absent(),
    this.hsn = const Value.absent(),
    this.foodCostMinor = const Value.absent(),
    this.channels = const Value.absent(),
    this.kitchenStation = const Value.absent(),
    this.menuStatus = const Value.absent(),
    this.availabilityLabel = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.dietType = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MenuItemsTableCompanion.insert({
    required String id,
    required String categoryId,
    required String name,
    required int priceMinor,
    this.isVeg = const Value.absent(),
    this.isBestseller = const Value.absent(),
    this.available = const Value.absent(),
    this.unavailableReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sku = const Value.absent(),
    this.hsn = const Value.absent(),
    this.foodCostMinor = const Value.absent(),
    this.channels = const Value.absent(),
    this.kitchenStation = const Value.absent(),
    this.menuStatus = const Value.absent(),
    this.availabilityLabel = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.dietType = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        categoryId = Value(categoryId),
        name = Value(name),
        priceMinor = Value(priceMinor);
  static Insertable<MenuItemEntity> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<int>? priceMinor,
    Expression<bool>? isVeg,
    Expression<bool>? isBestseller,
    Expression<bool>? available,
    Expression<String>? unavailableReason,
    Expression<DateTime>? createdAt,
    Expression<String>? sku,
    Expression<String>? hsn,
    Expression<int>? foodCostMinor,
    Expression<String>? channels,
    Expression<String>? kitchenStation,
    Expression<String>? menuStatus,
    Expression<String>? availabilityLabel,
    Expression<String>? imageUrl,
    Expression<String>? dietType,
    Expression<String>? detailsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (priceMinor != null) 'price_minor': priceMinor,
      if (isVeg != null) 'is_veg': isVeg,
      if (isBestseller != null) 'is_bestseller': isBestseller,
      if (available != null) 'available': available,
      if (unavailableReason != null) 'unavailable_reason': unavailableReason,
      if (createdAt != null) 'created_at': createdAt,
      if (sku != null) 'sku': sku,
      if (hsn != null) 'hsn': hsn,
      if (foodCostMinor != null) 'food_cost_minor': foodCostMinor,
      if (channels != null) 'channels': channels,
      if (kitchenStation != null) 'kitchen_station': kitchenStation,
      if (menuStatus != null) 'menu_status': menuStatus,
      if (availabilityLabel != null) 'availability_label': availabilityLabel,
      if (imageUrl != null) 'image_url': imageUrl,
      if (dietType != null) 'diet_type': dietType,
      if (detailsJson != null) 'details_json': detailsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MenuItemsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? categoryId,
      Value<String>? name,
      Value<int>? priceMinor,
      Value<bool>? isVeg,
      Value<bool>? isBestseller,
      Value<bool>? available,
      Value<String?>? unavailableReason,
      Value<DateTime>? createdAt,
      Value<String>? sku,
      Value<String>? hsn,
      Value<int>? foodCostMinor,
      Value<String>? channels,
      Value<String>? kitchenStation,
      Value<String>? menuStatus,
      Value<String>? availabilityLabel,
      Value<String>? imageUrl,
      Value<String>? dietType,
      Value<String>? detailsJson,
      Value<int>? rowid}) {
    return MenuItemsTableCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      priceMinor: priceMinor ?? this.priceMinor,
      isVeg: isVeg ?? this.isVeg,
      isBestseller: isBestseller ?? this.isBestseller,
      available: available ?? this.available,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      createdAt: createdAt ?? this.createdAt,
      sku: sku ?? this.sku,
      hsn: hsn ?? this.hsn,
      foodCostMinor: foodCostMinor ?? this.foodCostMinor,
      channels: channels ?? this.channels,
      kitchenStation: kitchenStation ?? this.kitchenStation,
      menuStatus: menuStatus ?? this.menuStatus,
      availabilityLabel: availabilityLabel ?? this.availabilityLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      dietType: dietType ?? this.dietType,
      detailsJson: detailsJson ?? this.detailsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priceMinor.present) {
      map['price_minor'] = Variable<int>(priceMinor.value);
    }
    if (isVeg.present) {
      map['is_veg'] = Variable<bool>(isVeg.value);
    }
    if (isBestseller.present) {
      map['is_bestseller'] = Variable<bool>(isBestseller.value);
    }
    if (available.present) {
      map['available'] = Variable<bool>(available.value);
    }
    if (unavailableReason.present) {
      map['unavailable_reason'] = Variable<String>(unavailableReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (hsn.present) {
      map['hsn'] = Variable<String>(hsn.value);
    }
    if (foodCostMinor.present) {
      map['food_cost_minor'] = Variable<int>(foodCostMinor.value);
    }
    if (channels.present) {
      map['channels'] = Variable<String>(channels.value);
    }
    if (kitchenStation.present) {
      map['kitchen_station'] = Variable<String>(kitchenStation.value);
    }
    if (menuStatus.present) {
      map['menu_status'] = Variable<String>(menuStatus.value);
    }
    if (availabilityLabel.present) {
      map['availability_label'] = Variable<String>(availabilityLabel.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (dietType.present) {
      map['diet_type'] = Variable<String>(dietType.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenuItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('isVeg: $isVeg, ')
          ..write('isBestseller: $isBestseller, ')
          ..write('available: $available, ')
          ..write('unavailableReason: $unavailableReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('sku: $sku, ')
          ..write('hsn: $hsn, ')
          ..write('foodCostMinor: $foodCostMinor, ')
          ..write('channels: $channels, ')
          ..write('kitchenStation: $kitchenStation, ')
          ..write('menuStatus: $menuStatus, ')
          ..write('availabilityLabel: $availabilityLabel, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('dietType: $dietType, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<AppMetadataRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetadataRow extends DataClass implements Insertable<AppMetadataRow> {
  final String key;
  final String value;
  const AppMetadataRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppMetadataRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetadataRow copyWith({String? key, String? value}) => AppMetadataRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppMetadataRow copyWithCompanion(AppMetadataCompanion data) {
    return AppMetadataRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetadataRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppMetadataRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RawMaterialsTableTable extends RawMaterialsTable
    with TableInfo<$RawMaterialsTableTable, RawMaterialEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RawMaterialsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stockQtyMeta =
      const VerificationMeta('stockQty');
  @override
  late final GeneratedColumn<double> stockQty = GeneratedColumn<double>(
      'stock_qty', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _reorderLevelMeta =
      const VerificationMeta('reorderLevel');
  @override
  late final GeneratedColumn<double> reorderLevel = GeneratedColumn<double>(
      'reorder_level', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _maxCapacityMeta =
      const VerificationMeta('maxCapacity');
  @override
  late final GeneratedColumn<double> maxCapacity = GeneratedColumn<double>(
      'max_capacity', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _purchaseCostMeta =
      const VerificationMeta('purchaseCost');
  @override
  late final GeneratedColumn<double> purchaseCost = GeneratedColumn<double>(
      'purchase_cost', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastPurchasePriceMeta =
      const VerificationMeta('lastPurchasePrice');
  @override
  late final GeneratedColumn<double> lastPurchasePrice =
      GeneratedColumn<double>('last_purchase_price', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _preferredSupplierIdMeta =
      const VerificationMeta('preferredSupplierId');
  @override
  late final GeneratedColumn<String> preferredSupplierId =
      GeneratedColumn<String>('preferred_supplier_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _hsnMeta = const VerificationMeta('hsn');
  @override
  late final GeneratedColumn<String> hsn = GeneratedColumn<String>(
      'hsn', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('📦'));
  static const VerificationMeta _leadTimeDaysMeta =
      const VerificationMeta('leadTimeDays');
  @override
  late final GeneratedColumn<int> leadTimeDays = GeneratedColumn<int>(
      'lead_time_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2));
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        code,
        name,
        category,
        unit,
        stockQty,
        reorderLevel,
        maxCapacity,
        purchaseCost,
        lastPurchasePrice,
        preferredSupplierId,
        hsn,
        emoji,
        leadTimeDays,
        active,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'raw_materials_table';
  @override
  VerificationContext validateIntegrity(Insertable<RawMaterialEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('stock_qty')) {
      context.handle(_stockQtyMeta,
          stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta));
    }
    if (data.containsKey('reorder_level')) {
      context.handle(
          _reorderLevelMeta,
          reorderLevel.isAcceptableOrUnknown(
              data['reorder_level']!, _reorderLevelMeta));
    }
    if (data.containsKey('max_capacity')) {
      context.handle(
          _maxCapacityMeta,
          maxCapacity.isAcceptableOrUnknown(
              data['max_capacity']!, _maxCapacityMeta));
    }
    if (data.containsKey('purchase_cost')) {
      context.handle(
          _purchaseCostMeta,
          purchaseCost.isAcceptableOrUnknown(
              data['purchase_cost']!, _purchaseCostMeta));
    }
    if (data.containsKey('last_purchase_price')) {
      context.handle(
          _lastPurchasePriceMeta,
          lastPurchasePrice.isAcceptableOrUnknown(
              data['last_purchase_price']!, _lastPurchasePriceMeta));
    }
    if (data.containsKey('preferred_supplier_id')) {
      context.handle(
          _preferredSupplierIdMeta,
          preferredSupplierId.isAcceptableOrUnknown(
              data['preferred_supplier_id']!, _preferredSupplierIdMeta));
    }
    if (data.containsKey('hsn')) {
      context.handle(
          _hsnMeta, hsn.isAcceptableOrUnknown(data['hsn']!, _hsnMeta));
    }
    if (data.containsKey('emoji')) {
      context.handle(
          _emojiMeta, emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta));
    }
    if (data.containsKey('lead_time_days')) {
      context.handle(
          _leadTimeDaysMeta,
          leadTimeDays.isAcceptableOrUnknown(
              data['lead_time_days']!, _leadTimeDaysMeta));
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RawMaterialEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawMaterialEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      stockQty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stock_qty'])!,
      reorderLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}reorder_level'])!,
      maxCapacity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}max_capacity'])!,
      purchaseCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}purchase_cost'])!,
      lastPurchasePrice: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}last_purchase_price']),
      preferredSupplierId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preferred_supplier_id']),
      hsn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hsn'])!,
      emoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emoji'])!,
      leadTimeDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lead_time_days'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $RawMaterialsTableTable createAlias(String alias) {
    return $RawMaterialsTableTable(attachedDatabase, alias);
  }
}

class RawMaterialEntity extends DataClass
    implements Insertable<RawMaterialEntity> {
  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double stockQty;
  final double reorderLevel;
  final double maxCapacity;
  final double purchaseCost;
  final double? lastPurchasePrice;
  final String? preferredSupplierId;
  final String hsn;
  final String emoji;
  final int leadTimeDays;
  final bool active;
  final DateTime createdAt;
  const RawMaterialEntity(
      {required this.id,
      required this.code,
      required this.name,
      required this.category,
      required this.unit,
      required this.stockQty,
      required this.reorderLevel,
      required this.maxCapacity,
      required this.purchaseCost,
      this.lastPurchasePrice,
      this.preferredSupplierId,
      required this.hsn,
      required this.emoji,
      required this.leadTimeDays,
      required this.active,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['unit'] = Variable<String>(unit);
    map['stock_qty'] = Variable<double>(stockQty);
    map['reorder_level'] = Variable<double>(reorderLevel);
    map['max_capacity'] = Variable<double>(maxCapacity);
    map['purchase_cost'] = Variable<double>(purchaseCost);
    if (!nullToAbsent || lastPurchasePrice != null) {
      map['last_purchase_price'] = Variable<double>(lastPurchasePrice);
    }
    if (!nullToAbsent || preferredSupplierId != null) {
      map['preferred_supplier_id'] = Variable<String>(preferredSupplierId);
    }
    map['hsn'] = Variable<String>(hsn);
    map['emoji'] = Variable<String>(emoji);
    map['lead_time_days'] = Variable<int>(leadTimeDays);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RawMaterialsTableCompanion toCompanion(bool nullToAbsent) {
    return RawMaterialsTableCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      category: Value(category),
      unit: Value(unit),
      stockQty: Value(stockQty),
      reorderLevel: Value(reorderLevel),
      maxCapacity: Value(maxCapacity),
      purchaseCost: Value(purchaseCost),
      lastPurchasePrice: lastPurchasePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPurchasePrice),
      preferredSupplierId: preferredSupplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSupplierId),
      hsn: Value(hsn),
      emoji: Value(emoji),
      leadTimeDays: Value(leadTimeDays),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory RawMaterialEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawMaterialEntity(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      unit: serializer.fromJson<String>(json['unit']),
      stockQty: serializer.fromJson<double>(json['stockQty']),
      reorderLevel: serializer.fromJson<double>(json['reorderLevel']),
      maxCapacity: serializer.fromJson<double>(json['maxCapacity']),
      purchaseCost: serializer.fromJson<double>(json['purchaseCost']),
      lastPurchasePrice:
          serializer.fromJson<double?>(json['lastPurchasePrice']),
      preferredSupplierId:
          serializer.fromJson<String?>(json['preferredSupplierId']),
      hsn: serializer.fromJson<String>(json['hsn']),
      emoji: serializer.fromJson<String>(json['emoji']),
      leadTimeDays: serializer.fromJson<int>(json['leadTimeDays']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'unit': serializer.toJson<String>(unit),
      'stockQty': serializer.toJson<double>(stockQty),
      'reorderLevel': serializer.toJson<double>(reorderLevel),
      'maxCapacity': serializer.toJson<double>(maxCapacity),
      'purchaseCost': serializer.toJson<double>(purchaseCost),
      'lastPurchasePrice': serializer.toJson<double?>(lastPurchasePrice),
      'preferredSupplierId': serializer.toJson<String?>(preferredSupplierId),
      'hsn': serializer.toJson<String>(hsn),
      'emoji': serializer.toJson<String>(emoji),
      'leadTimeDays': serializer.toJson<int>(leadTimeDays),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RawMaterialEntity copyWith(
          {String? id,
          String? code,
          String? name,
          String? category,
          String? unit,
          double? stockQty,
          double? reorderLevel,
          double? maxCapacity,
          double? purchaseCost,
          Value<double?> lastPurchasePrice = const Value.absent(),
          Value<String?> preferredSupplierId = const Value.absent(),
          String? hsn,
          String? emoji,
          int? leadTimeDays,
          bool? active,
          DateTime? createdAt}) =>
      RawMaterialEntity(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        stockQty: stockQty ?? this.stockQty,
        reorderLevel: reorderLevel ?? this.reorderLevel,
        maxCapacity: maxCapacity ?? this.maxCapacity,
        purchaseCost: purchaseCost ?? this.purchaseCost,
        lastPurchasePrice: lastPurchasePrice.present
            ? lastPurchasePrice.value
            : this.lastPurchasePrice,
        preferredSupplierId: preferredSupplierId.present
            ? preferredSupplierId.value
            : this.preferredSupplierId,
        hsn: hsn ?? this.hsn,
        emoji: emoji ?? this.emoji,
        leadTimeDays: leadTimeDays ?? this.leadTimeDays,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
      );
  RawMaterialEntity copyWithCompanion(RawMaterialsTableCompanion data) {
    return RawMaterialEntity(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      unit: data.unit.present ? data.unit.value : this.unit,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      reorderLevel: data.reorderLevel.present
          ? data.reorderLevel.value
          : this.reorderLevel,
      maxCapacity:
          data.maxCapacity.present ? data.maxCapacity.value : this.maxCapacity,
      purchaseCost: data.purchaseCost.present
          ? data.purchaseCost.value
          : this.purchaseCost,
      lastPurchasePrice: data.lastPurchasePrice.present
          ? data.lastPurchasePrice.value
          : this.lastPurchasePrice,
      preferredSupplierId: data.preferredSupplierId.present
          ? data.preferredSupplierId.value
          : this.preferredSupplierId,
      hsn: data.hsn.present ? data.hsn.value : this.hsn,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      leadTimeDays: data.leadTimeDays.present
          ? data.leadTimeDays.value
          : this.leadTimeDays,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawMaterialEntity(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('stockQty: $stockQty, ')
          ..write('reorderLevel: $reorderLevel, ')
          ..write('maxCapacity: $maxCapacity, ')
          ..write('purchaseCost: $purchaseCost, ')
          ..write('lastPurchasePrice: $lastPurchasePrice, ')
          ..write('preferredSupplierId: $preferredSupplierId, ')
          ..write('hsn: $hsn, ')
          ..write('emoji: $emoji, ')
          ..write('leadTimeDays: $leadTimeDays, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      code,
      name,
      category,
      unit,
      stockQty,
      reorderLevel,
      maxCapacity,
      purchaseCost,
      lastPurchasePrice,
      preferredSupplierId,
      hsn,
      emoji,
      leadTimeDays,
      active,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawMaterialEntity &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.category == this.category &&
          other.unit == this.unit &&
          other.stockQty == this.stockQty &&
          other.reorderLevel == this.reorderLevel &&
          other.maxCapacity == this.maxCapacity &&
          other.purchaseCost == this.purchaseCost &&
          other.lastPurchasePrice == this.lastPurchasePrice &&
          other.preferredSupplierId == this.preferredSupplierId &&
          other.hsn == this.hsn &&
          other.emoji == this.emoji &&
          other.leadTimeDays == this.leadTimeDays &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class RawMaterialsTableCompanion extends UpdateCompanion<RawMaterialEntity> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> category;
  final Value<String> unit;
  final Value<double> stockQty;
  final Value<double> reorderLevel;
  final Value<double> maxCapacity;
  final Value<double> purchaseCost;
  final Value<double?> lastPurchasePrice;
  final Value<String?> preferredSupplierId;
  final Value<String> hsn;
  final Value<String> emoji;
  final Value<int> leadTimeDays;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RawMaterialsTableCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.reorderLevel = const Value.absent(),
    this.maxCapacity = const Value.absent(),
    this.purchaseCost = const Value.absent(),
    this.lastPurchasePrice = const Value.absent(),
    this.preferredSupplierId = const Value.absent(),
    this.hsn = const Value.absent(),
    this.emoji = const Value.absent(),
    this.leadTimeDays = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RawMaterialsTableCompanion.insert({
    required String id,
    required String code,
    required String name,
    required String category,
    required String unit,
    this.stockQty = const Value.absent(),
    this.reorderLevel = const Value.absent(),
    this.maxCapacity = const Value.absent(),
    this.purchaseCost = const Value.absent(),
    this.lastPurchasePrice = const Value.absent(),
    this.preferredSupplierId = const Value.absent(),
    this.hsn = const Value.absent(),
    this.emoji = const Value.absent(),
    this.leadTimeDays = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        code = Value(code),
        name = Value(name),
        category = Value(category),
        unit = Value(unit);
  static Insertable<RawMaterialEntity> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? unit,
    Expression<double>? stockQty,
    Expression<double>? reorderLevel,
    Expression<double>? maxCapacity,
    Expression<double>? purchaseCost,
    Expression<double>? lastPurchasePrice,
    Expression<String>? preferredSupplierId,
    Expression<String>? hsn,
    Expression<String>? emoji,
    Expression<int>? leadTimeDays,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (stockQty != null) 'stock_qty': stockQty,
      if (reorderLevel != null) 'reorder_level': reorderLevel,
      if (maxCapacity != null) 'max_capacity': maxCapacity,
      if (purchaseCost != null) 'purchase_cost': purchaseCost,
      if (lastPurchasePrice != null) 'last_purchase_price': lastPurchasePrice,
      if (preferredSupplierId != null)
        'preferred_supplier_id': preferredSupplierId,
      if (hsn != null) 'hsn': hsn,
      if (emoji != null) 'emoji': emoji,
      if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RawMaterialsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? code,
      Value<String>? name,
      Value<String>? category,
      Value<String>? unit,
      Value<double>? stockQty,
      Value<double>? reorderLevel,
      Value<double>? maxCapacity,
      Value<double>? purchaseCost,
      Value<double?>? lastPurchasePrice,
      Value<String?>? preferredSupplierId,
      Value<String>? hsn,
      Value<String>? emoji,
      Value<int>? leadTimeDays,
      Value<bool>? active,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return RawMaterialsTableCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      stockQty: stockQty ?? this.stockQty,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      preferredSupplierId: preferredSupplierId ?? this.preferredSupplierId,
      hsn: hsn ?? this.hsn,
      emoji: emoji ?? this.emoji,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<double>(stockQty.value);
    }
    if (reorderLevel.present) {
      map['reorder_level'] = Variable<double>(reorderLevel.value);
    }
    if (maxCapacity.present) {
      map['max_capacity'] = Variable<double>(maxCapacity.value);
    }
    if (purchaseCost.present) {
      map['purchase_cost'] = Variable<double>(purchaseCost.value);
    }
    if (lastPurchasePrice.present) {
      map['last_purchase_price'] = Variable<double>(lastPurchasePrice.value);
    }
    if (preferredSupplierId.present) {
      map['preferred_supplier_id'] =
          Variable<String>(preferredSupplierId.value);
    }
    if (hsn.present) {
      map['hsn'] = Variable<String>(hsn.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (leadTimeDays.present) {
      map['lead_time_days'] = Variable<int>(leadTimeDays.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RawMaterialsTableCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('stockQty: $stockQty, ')
          ..write('reorderLevel: $reorderLevel, ')
          ..write('maxCapacity: $maxCapacity, ')
          ..write('purchaseCost: $purchaseCost, ')
          ..write('lastPurchasePrice: $lastPurchasePrice, ')
          ..write('preferredSupplierId: $preferredSupplierId, ')
          ..write('hsn: $hsn, ')
          ..write('emoji: $emoji, ')
          ..write('leadTimeDays: $leadTimeDays, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTableTable extends SuppliersTable
    with TableInfo<$SuppliersTableTable, SupplierEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _legalNameMeta =
      const VerificationMeta('legalName');
  @override
  late final GeneratedColumn<String> legalName = GeneratedColumn<String>(
      'legal_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _contactPersonMeta =
      const VerificationMeta('contactPerson');
  @override
  late final GeneratedColumn<String> contactPerson = GeneratedColumn<String>(
      'contact_person', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  @override
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
      'gstin', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
      'rating', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _paymentTermsMeta =
      const VerificationMeta('paymentTerms');
  @override
  late final GeneratedColumn<String> paymentTerms = GeneratedColumn<String>(
      'payment_terms', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Net 15 Days'));
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        legalName,
        category,
        contactPerson,
        phone,
        email,
        gstin,
        city,
        rating,
        paymentTerms,
        active,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers_table';
  @override
  VerificationContext validateIntegrity(Insertable<SupplierEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('legal_name')) {
      context.handle(_legalNameMeta,
          legalName.isAcceptableOrUnknown(data['legal_name']!, _legalNameMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('contact_person')) {
      context.handle(
          _contactPersonMeta,
          contactPerson.isAcceptableOrUnknown(
              data['contact_person']!, _contactPersonMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('gstin')) {
      context.handle(
          _gstinMeta, gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('payment_terms')) {
      context.handle(
          _paymentTermsMeta,
          paymentTerms.isAcceptableOrUnknown(
              data['payment_terms']!, _paymentTermsMeta));
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplierEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplierEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      legalName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}legal_name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      contactPerson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_person'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      gstin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gstin'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rating'])!,
      paymentTerms: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_terms'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SuppliersTableTable createAlias(String alias) {
    return $SuppliersTableTable(attachedDatabase, alias);
  }
}

class SupplierEntity extends DataClass implements Insertable<SupplierEntity> {
  final String id;
  final String name;
  final String legalName;
  final String category;
  final String contactPerson;
  final String phone;
  final String email;
  final String gstin;
  final String city;
  final double rating;
  final String paymentTerms;
  final bool active;
  final DateTime createdAt;
  const SupplierEntity(
      {required this.id,
      required this.name,
      required this.legalName,
      required this.category,
      required this.contactPerson,
      required this.phone,
      required this.email,
      required this.gstin,
      required this.city,
      required this.rating,
      required this.paymentTerms,
      required this.active,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['legal_name'] = Variable<String>(legalName);
    map['category'] = Variable<String>(category);
    map['contact_person'] = Variable<String>(contactPerson);
    map['phone'] = Variable<String>(phone);
    map['email'] = Variable<String>(email);
    map['gstin'] = Variable<String>(gstin);
    map['city'] = Variable<String>(city);
    map['rating'] = Variable<double>(rating);
    map['payment_terms'] = Variable<String>(paymentTerms);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SuppliersTableCompanion toCompanion(bool nullToAbsent) {
    return SuppliersTableCompanion(
      id: Value(id),
      name: Value(name),
      legalName: Value(legalName),
      category: Value(category),
      contactPerson: Value(contactPerson),
      phone: Value(phone),
      email: Value(email),
      gstin: Value(gstin),
      city: Value(city),
      rating: Value(rating),
      paymentTerms: Value(paymentTerms),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory SupplierEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplierEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      legalName: serializer.fromJson<String>(json['legalName']),
      category: serializer.fromJson<String>(json['category']),
      contactPerson: serializer.fromJson<String>(json['contactPerson']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String>(json['email']),
      gstin: serializer.fromJson<String>(json['gstin']),
      city: serializer.fromJson<String>(json['city']),
      rating: serializer.fromJson<double>(json['rating']),
      paymentTerms: serializer.fromJson<String>(json['paymentTerms']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'legalName': serializer.toJson<String>(legalName),
      'category': serializer.toJson<String>(category),
      'contactPerson': serializer.toJson<String>(contactPerson),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String>(email),
      'gstin': serializer.toJson<String>(gstin),
      'city': serializer.toJson<String>(city),
      'rating': serializer.toJson<double>(rating),
      'paymentTerms': serializer.toJson<String>(paymentTerms),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SupplierEntity copyWith(
          {String? id,
          String? name,
          String? legalName,
          String? category,
          String? contactPerson,
          String? phone,
          String? email,
          String? gstin,
          String? city,
          double? rating,
          String? paymentTerms,
          bool? active,
          DateTime? createdAt}) =>
      SupplierEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        legalName: legalName ?? this.legalName,
        category: category ?? this.category,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gstin: gstin ?? this.gstin,
        city: city ?? this.city,
        rating: rating ?? this.rating,
        paymentTerms: paymentTerms ?? this.paymentTerms,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
      );
  SupplierEntity copyWithCompanion(SuppliersTableCompanion data) {
    return SupplierEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      legalName: data.legalName.present ? data.legalName.value : this.legalName,
      category: data.category.present ? data.category.value : this.category,
      contactPerson: data.contactPerson.present
          ? data.contactPerson.value
          : this.contactPerson,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      city: data.city.present ? data.city.value : this.city,
      rating: data.rating.present ? data.rating.value : this.rating,
      paymentTerms: data.paymentTerms.present
          ? data.paymentTerms.value
          : this.paymentTerms,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplierEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('legalName: $legalName, ')
          ..write('category: $category, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('gstin: $gstin, ')
          ..write('city: $city, ')
          ..write('rating: $rating, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, legalName, category, contactPerson,
      phone, email, gstin, city, rating, paymentTerms, active, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplierEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.legalName == this.legalName &&
          other.category == this.category &&
          other.contactPerson == this.contactPerson &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.gstin == this.gstin &&
          other.city == this.city &&
          other.rating == this.rating &&
          other.paymentTerms == this.paymentTerms &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class SuppliersTableCompanion extends UpdateCompanion<SupplierEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> legalName;
  final Value<String> category;
  final Value<String> contactPerson;
  final Value<String> phone;
  final Value<String> email;
  final Value<String> gstin;
  final Value<String> city;
  final Value<double> rating;
  final Value<String> paymentTerms;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SuppliersTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.legalName = const Value.absent(),
    this.category = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.gstin = const Value.absent(),
    this.city = const Value.absent(),
    this.rating = const Value.absent(),
    this.paymentTerms = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersTableCompanion.insert({
    required String id,
    required String name,
    this.legalName = const Value.absent(),
    this.category = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.gstin = const Value.absent(),
    this.city = const Value.absent(),
    this.rating = const Value.absent(),
    this.paymentTerms = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<SupplierEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? legalName,
    Expression<String>? category,
    Expression<String>? contactPerson,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? gstin,
    Expression<String>? city,
    Expression<double>? rating,
    Expression<String>? paymentTerms,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (legalName != null) 'legal_name': legalName,
      if (category != null) 'category': category,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (gstin != null) 'gstin': gstin,
      if (city != null) 'city': city,
      if (rating != null) 'rating': rating,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? legalName,
      Value<String>? category,
      Value<String>? contactPerson,
      Value<String>? phone,
      Value<String>? email,
      Value<String>? gstin,
      Value<String>? city,
      Value<double>? rating,
      Value<String>? paymentTerms,
      Value<bool>? active,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SuppliersTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      category: category ?? this.category,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      city: city ?? this.city,
      rating: rating ?? this.rating,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (legalName.present) {
      map['legal_name'] = Variable<String>(legalName.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (contactPerson.present) {
      map['contact_person'] = Variable<String>(contactPerson.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (paymentTerms.present) {
      map['payment_terms'] = Variable<String>(paymentTerms.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('legalName: $legalName, ')
          ..write('category: $category, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('gstin: $gstin, ')
          ..write('city: $city, ')
          ..write('rating: $rating, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SupplierPricesTableTable extends SupplierPricesTable
    with TableInfo<$SupplierPricesTableTable, SupplierPriceEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupplierPricesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ingredientNameMeta =
      const VerificationMeta('ingredientName');
  @override
  late final GeneratedColumn<String> ingredientName = GeneratedColumn<String>(
      'ingredient_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _materialIdMeta =
      const VerificationMeta('materialId');
  @override
  late final GeneratedColumn<String> materialId = GeneratedColumn<String>(
      'material_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('📦'));
  static const VerificationMeta _linkedToMeta =
      const VerificationMeta('linkedTo');
  @override
  late final GeneratedColumn<String> linkedTo = GeneratedColumn<String>(
      'linked_to', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _supplierIdMeta =
      const VerificationMeta('supplierId');
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
      'supplier_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastPriceMeta =
      const VerificationMeta('lastPrice');
  @override
  late final GeneratedColumn<double> lastPrice = GeneratedColumn<double>(
      'last_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currentPriceMeta =
      const VerificationMeta('currentPrice');
  @override
  late final GeneratedColumn<double> currentPrice = GeneratedColumn<double>(
      'current_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lowestWeekMeta =
      const VerificationMeta('lowestWeek');
  @override
  late final GeneratedColumn<double> lowestWeek = GeneratedColumn<double>(
      'lowest_week', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Medium'));
  static const VerificationMeta _skuIdMeta = const VerificationMeta('skuId');
  @override
  late final GeneratedColumn<String> skuId = GeneratedColumn<String>(
      'sku_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _approvedMeta =
      const VerificationMeta('approved');
  @override
  late final GeneratedColumn<bool> approved = GeneratedColumn<bool>(
      'approved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("approved" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ingredientName,
        materialId,
        emoji,
        linkedTo,
        supplierId,
        unit,
        lastPrice,
        currentPrice,
        lowestWeek,
        source,
        priority,
        skuId,
        approved,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplier_prices_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<SupplierPriceEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ingredient_name')) {
      context.handle(
          _ingredientNameMeta,
          ingredientName.isAcceptableOrUnknown(
              data['ingredient_name']!, _ingredientNameMeta));
    } else if (isInserting) {
      context.missing(_ingredientNameMeta);
    }
    if (data.containsKey('material_id')) {
      context.handle(
          _materialIdMeta,
          materialId.isAcceptableOrUnknown(
              data['material_id']!, _materialIdMeta));
    }
    if (data.containsKey('emoji')) {
      context.handle(
          _emojiMeta, emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta));
    }
    if (data.containsKey('linked_to')) {
      context.handle(_linkedToMeta,
          linkedTo.isAcceptableOrUnknown(data['linked_to']!, _linkedToMeta));
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
          _supplierIdMeta,
          supplierId.isAcceptableOrUnknown(
              data['supplier_id']!, _supplierIdMeta));
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('last_price')) {
      context.handle(_lastPriceMeta,
          lastPrice.isAcceptableOrUnknown(data['last_price']!, _lastPriceMeta));
    } else if (isInserting) {
      context.missing(_lastPriceMeta);
    }
    if (data.containsKey('current_price')) {
      context.handle(
          _currentPriceMeta,
          currentPrice.isAcceptableOrUnknown(
              data['current_price']!, _currentPriceMeta));
    } else if (isInserting) {
      context.missing(_currentPriceMeta);
    }
    if (data.containsKey('lowest_week')) {
      context.handle(
          _lowestWeekMeta,
          lowestWeek.isAcceptableOrUnknown(
              data['lowest_week']!, _lowestWeekMeta));
    } else if (isInserting) {
      context.missing(_lowestWeekMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('sku_id')) {
      context.handle(
          _skuIdMeta, skuId.isAcceptableOrUnknown(data['sku_id']!, _skuIdMeta));
    }
    if (data.containsKey('approved')) {
      context.handle(_approvedMeta,
          approved.isAcceptableOrUnknown(data['approved']!, _approvedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupplierPriceEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupplierPriceEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ingredientName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}ingredient_name'])!,
      materialId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material_id']),
      emoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emoji'])!,
      linkedTo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}linked_to'])!,
      supplierId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_id'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      lastPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}last_price'])!,
      currentPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}current_price'])!,
      lowestWeek: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lowest_week'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      skuId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku_id'])!,
      approved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}approved'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SupplierPricesTableTable createAlias(String alias) {
    return $SupplierPricesTableTable(attachedDatabase, alias);
  }
}

class SupplierPriceEntity extends DataClass
    implements Insertable<SupplierPriceEntity> {
  final String id;
  final String ingredientName;
  final String? materialId;
  final String emoji;
  final String linkedTo;
  final String supplierId;
  final String unit;
  final double lastPrice;
  final double currentPrice;
  final double lowestWeek;
  final String source;
  final String priority;
  final String skuId;
  final bool approved;
  final DateTime updatedAt;
  const SupplierPriceEntity(
      {required this.id,
      required this.ingredientName,
      this.materialId,
      required this.emoji,
      required this.linkedTo,
      required this.supplierId,
      required this.unit,
      required this.lastPrice,
      required this.currentPrice,
      required this.lowestWeek,
      required this.source,
      required this.priority,
      required this.skuId,
      required this.approved,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ingredient_name'] = Variable<String>(ingredientName);
    if (!nullToAbsent || materialId != null) {
      map['material_id'] = Variable<String>(materialId);
    }
    map['emoji'] = Variable<String>(emoji);
    map['linked_to'] = Variable<String>(linkedTo);
    map['supplier_id'] = Variable<String>(supplierId);
    map['unit'] = Variable<String>(unit);
    map['last_price'] = Variable<double>(lastPrice);
    map['current_price'] = Variable<double>(currentPrice);
    map['lowest_week'] = Variable<double>(lowestWeek);
    map['source'] = Variable<String>(source);
    map['priority'] = Variable<String>(priority);
    map['sku_id'] = Variable<String>(skuId);
    map['approved'] = Variable<bool>(approved);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SupplierPricesTableCompanion toCompanion(bool nullToAbsent) {
    return SupplierPricesTableCompanion(
      id: Value(id),
      ingredientName: Value(ingredientName),
      materialId: materialId == null && nullToAbsent
          ? const Value.absent()
          : Value(materialId),
      emoji: Value(emoji),
      linkedTo: Value(linkedTo),
      supplierId: Value(supplierId),
      unit: Value(unit),
      lastPrice: Value(lastPrice),
      currentPrice: Value(currentPrice),
      lowestWeek: Value(lowestWeek),
      source: Value(source),
      priority: Value(priority),
      skuId: Value(skuId),
      approved: Value(approved),
      updatedAt: Value(updatedAt),
    );
  }

  factory SupplierPriceEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupplierPriceEntity(
      id: serializer.fromJson<String>(json['id']),
      ingredientName: serializer.fromJson<String>(json['ingredientName']),
      materialId: serializer.fromJson<String?>(json['materialId']),
      emoji: serializer.fromJson<String>(json['emoji']),
      linkedTo: serializer.fromJson<String>(json['linkedTo']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      unit: serializer.fromJson<String>(json['unit']),
      lastPrice: serializer.fromJson<double>(json['lastPrice']),
      currentPrice: serializer.fromJson<double>(json['currentPrice']),
      lowestWeek: serializer.fromJson<double>(json['lowestWeek']),
      source: serializer.fromJson<String>(json['source']),
      priority: serializer.fromJson<String>(json['priority']),
      skuId: serializer.fromJson<String>(json['skuId']),
      approved: serializer.fromJson<bool>(json['approved']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ingredientName': serializer.toJson<String>(ingredientName),
      'materialId': serializer.toJson<String?>(materialId),
      'emoji': serializer.toJson<String>(emoji),
      'linkedTo': serializer.toJson<String>(linkedTo),
      'supplierId': serializer.toJson<String>(supplierId),
      'unit': serializer.toJson<String>(unit),
      'lastPrice': serializer.toJson<double>(lastPrice),
      'currentPrice': serializer.toJson<double>(currentPrice),
      'lowestWeek': serializer.toJson<double>(lowestWeek),
      'source': serializer.toJson<String>(source),
      'priority': serializer.toJson<String>(priority),
      'skuId': serializer.toJson<String>(skuId),
      'approved': serializer.toJson<bool>(approved),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SupplierPriceEntity copyWith(
          {String? id,
          String? ingredientName,
          Value<String?> materialId = const Value.absent(),
          String? emoji,
          String? linkedTo,
          String? supplierId,
          String? unit,
          double? lastPrice,
          double? currentPrice,
          double? lowestWeek,
          String? source,
          String? priority,
          String? skuId,
          bool? approved,
          DateTime? updatedAt}) =>
      SupplierPriceEntity(
        id: id ?? this.id,
        ingredientName: ingredientName ?? this.ingredientName,
        materialId: materialId.present ? materialId.value : this.materialId,
        emoji: emoji ?? this.emoji,
        linkedTo: linkedTo ?? this.linkedTo,
        supplierId: supplierId ?? this.supplierId,
        unit: unit ?? this.unit,
        lastPrice: lastPrice ?? this.lastPrice,
        currentPrice: currentPrice ?? this.currentPrice,
        lowestWeek: lowestWeek ?? this.lowestWeek,
        source: source ?? this.source,
        priority: priority ?? this.priority,
        skuId: skuId ?? this.skuId,
        approved: approved ?? this.approved,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SupplierPriceEntity copyWithCompanion(SupplierPricesTableCompanion data) {
    return SupplierPriceEntity(
      id: data.id.present ? data.id.value : this.id,
      ingredientName: data.ingredientName.present
          ? data.ingredientName.value
          : this.ingredientName,
      materialId:
          data.materialId.present ? data.materialId.value : this.materialId,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      linkedTo: data.linkedTo.present ? data.linkedTo.value : this.linkedTo,
      supplierId:
          data.supplierId.present ? data.supplierId.value : this.supplierId,
      unit: data.unit.present ? data.unit.value : this.unit,
      lastPrice: data.lastPrice.present ? data.lastPrice.value : this.lastPrice,
      currentPrice: data.currentPrice.present
          ? data.currentPrice.value
          : this.currentPrice,
      lowestWeek:
          data.lowestWeek.present ? data.lowestWeek.value : this.lowestWeek,
      source: data.source.present ? data.source.value : this.source,
      priority: data.priority.present ? data.priority.value : this.priority,
      skuId: data.skuId.present ? data.skuId.value : this.skuId,
      approved: data.approved.present ? data.approved.value : this.approved,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupplierPriceEntity(')
          ..write('id: $id, ')
          ..write('ingredientName: $ingredientName, ')
          ..write('materialId: $materialId, ')
          ..write('emoji: $emoji, ')
          ..write('linkedTo: $linkedTo, ')
          ..write('supplierId: $supplierId, ')
          ..write('unit: $unit, ')
          ..write('lastPrice: $lastPrice, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('lowestWeek: $lowestWeek, ')
          ..write('source: $source, ')
          ..write('priority: $priority, ')
          ..write('skuId: $skuId, ')
          ..write('approved: $approved, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ingredientName,
      materialId,
      emoji,
      linkedTo,
      supplierId,
      unit,
      lastPrice,
      currentPrice,
      lowestWeek,
      source,
      priority,
      skuId,
      approved,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupplierPriceEntity &&
          other.id == this.id &&
          other.ingredientName == this.ingredientName &&
          other.materialId == this.materialId &&
          other.emoji == this.emoji &&
          other.linkedTo == this.linkedTo &&
          other.supplierId == this.supplierId &&
          other.unit == this.unit &&
          other.lastPrice == this.lastPrice &&
          other.currentPrice == this.currentPrice &&
          other.lowestWeek == this.lowestWeek &&
          other.source == this.source &&
          other.priority == this.priority &&
          other.skuId == this.skuId &&
          other.approved == this.approved &&
          other.updatedAt == this.updatedAt);
}

class SupplierPricesTableCompanion
    extends UpdateCompanion<SupplierPriceEntity> {
  final Value<String> id;
  final Value<String> ingredientName;
  final Value<String?> materialId;
  final Value<String> emoji;
  final Value<String> linkedTo;
  final Value<String> supplierId;
  final Value<String> unit;
  final Value<double> lastPrice;
  final Value<double> currentPrice;
  final Value<double> lowestWeek;
  final Value<String> source;
  final Value<String> priority;
  final Value<String> skuId;
  final Value<bool> approved;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SupplierPricesTableCompanion({
    this.id = const Value.absent(),
    this.ingredientName = const Value.absent(),
    this.materialId = const Value.absent(),
    this.emoji = const Value.absent(),
    this.linkedTo = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.unit = const Value.absent(),
    this.lastPrice = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.lowestWeek = const Value.absent(),
    this.source = const Value.absent(),
    this.priority = const Value.absent(),
    this.skuId = const Value.absent(),
    this.approved = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupplierPricesTableCompanion.insert({
    required String id,
    required String ingredientName,
    this.materialId = const Value.absent(),
    this.emoji = const Value.absent(),
    this.linkedTo = const Value.absent(),
    required String supplierId,
    required String unit,
    required double lastPrice,
    required double currentPrice,
    required double lowestWeek,
    required String source,
    this.priority = const Value.absent(),
    this.skuId = const Value.absent(),
    this.approved = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        ingredientName = Value(ingredientName),
        supplierId = Value(supplierId),
        unit = Value(unit),
        lastPrice = Value(lastPrice),
        currentPrice = Value(currentPrice),
        lowestWeek = Value(lowestWeek),
        source = Value(source);
  static Insertable<SupplierPriceEntity> custom({
    Expression<String>? id,
    Expression<String>? ingredientName,
    Expression<String>? materialId,
    Expression<String>? emoji,
    Expression<String>? linkedTo,
    Expression<String>? supplierId,
    Expression<String>? unit,
    Expression<double>? lastPrice,
    Expression<double>? currentPrice,
    Expression<double>? lowestWeek,
    Expression<String>? source,
    Expression<String>? priority,
    Expression<String>? skuId,
    Expression<bool>? approved,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ingredientName != null) 'ingredient_name': ingredientName,
      if (materialId != null) 'material_id': materialId,
      if (emoji != null) 'emoji': emoji,
      if (linkedTo != null) 'linked_to': linkedTo,
      if (supplierId != null) 'supplier_id': supplierId,
      if (unit != null) 'unit': unit,
      if (lastPrice != null) 'last_price': lastPrice,
      if (currentPrice != null) 'current_price': currentPrice,
      if (lowestWeek != null) 'lowest_week': lowestWeek,
      if (source != null) 'source': source,
      if (priority != null) 'priority': priority,
      if (skuId != null) 'sku_id': skuId,
      if (approved != null) 'approved': approved,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupplierPricesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? ingredientName,
      Value<String?>? materialId,
      Value<String>? emoji,
      Value<String>? linkedTo,
      Value<String>? supplierId,
      Value<String>? unit,
      Value<double>? lastPrice,
      Value<double>? currentPrice,
      Value<double>? lowestWeek,
      Value<String>? source,
      Value<String>? priority,
      Value<String>? skuId,
      Value<bool>? approved,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SupplierPricesTableCompanion(
      id: id ?? this.id,
      ingredientName: ingredientName ?? this.ingredientName,
      materialId: materialId ?? this.materialId,
      emoji: emoji ?? this.emoji,
      linkedTo: linkedTo ?? this.linkedTo,
      supplierId: supplierId ?? this.supplierId,
      unit: unit ?? this.unit,
      lastPrice: lastPrice ?? this.lastPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      lowestWeek: lowestWeek ?? this.lowestWeek,
      source: source ?? this.source,
      priority: priority ?? this.priority,
      skuId: skuId ?? this.skuId,
      approved: approved ?? this.approved,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ingredientName.present) {
      map['ingredient_name'] = Variable<String>(ingredientName.value);
    }
    if (materialId.present) {
      map['material_id'] = Variable<String>(materialId.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (linkedTo.present) {
      map['linked_to'] = Variable<String>(linkedTo.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (lastPrice.present) {
      map['last_price'] = Variable<double>(lastPrice.value);
    }
    if (currentPrice.present) {
      map['current_price'] = Variable<double>(currentPrice.value);
    }
    if (lowestWeek.present) {
      map['lowest_week'] = Variable<double>(lowestWeek.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (skuId.present) {
      map['sku_id'] = Variable<String>(skuId.value);
    }
    if (approved.present) {
      map['approved'] = Variable<bool>(approved.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupplierPricesTableCompanion(')
          ..write('id: $id, ')
          ..write('ingredientName: $ingredientName, ')
          ..write('materialId: $materialId, ')
          ..write('emoji: $emoji, ')
          ..write('linkedTo: $linkedTo, ')
          ..write('supplierId: $supplierId, ')
          ..write('unit: $unit, ')
          ..write('lastPrice: $lastPrice, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('lowestWeek: $lowestWeek, ')
          ..write('source: $source, ')
          ..write('priority: $priority, ')
          ..write('skuId: $skuId, ')
          ..write('approved: $approved, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrdersTableTable extends PurchaseOrdersTable
    with TableInfo<$PurchaseOrdersTableTable, PurchaseOrderEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrdersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
      'number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _supplierIdMeta =
      const VerificationMeta('supplierId');
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
      'supplier_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderDateMeta =
      const VerificationMeta('orderDate');
  @override
  late final GeneratedColumn<DateTime> orderDate = GeneratedColumn<DateTime>(
      'order_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expectedDeliveryMeta =
      const VerificationMeta('expectedDelivery');
  @override
  late final GeneratedColumn<DateTime> expectedDelivery =
      GeneratedColumn<DateTime>('expected_delivery', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deliveryAddressMeta =
      const VerificationMeta('deliveryAddress');
  @override
  late final GeneratedColumn<String> deliveryAddress = GeneratedColumn<String>(
      'delivery_address', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deliveryCityMeta =
      const VerificationMeta('deliveryCity');
  @override
  late final GeneratedColumn<String> deliveryCity = GeneratedColumn<String>(
      'delivery_city', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _taxPctMeta = const VerificationMeta('taxPct');
  @override
  late final GeneratedColumn<double> taxPct = GeneratedColumn<double>(
      'tax_pct', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        number,
        supplierId,
        orderDate,
        expectedDelivery,
        status,
        createdBy,
        deliveryAddress,
        deliveryCity,
        taxPct,
        notes,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_orders_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<PurchaseOrderEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
          _supplierIdMeta,
          supplierId.isAcceptableOrUnknown(
              data['supplier_id']!, _supplierIdMeta));
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('order_date')) {
      context.handle(_orderDateMeta,
          orderDate.isAcceptableOrUnknown(data['order_date']!, _orderDateMeta));
    } else if (isInserting) {
      context.missing(_orderDateMeta);
    }
    if (data.containsKey('expected_delivery')) {
      context.handle(
          _expectedDeliveryMeta,
          expectedDelivery.isAcceptableOrUnknown(
              data['expected_delivery']!, _expectedDeliveryMeta));
    } else if (isInserting) {
      context.missing(_expectedDeliveryMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('delivery_address')) {
      context.handle(
          _deliveryAddressMeta,
          deliveryAddress.isAcceptableOrUnknown(
              data['delivery_address']!, _deliveryAddressMeta));
    }
    if (data.containsKey('delivery_city')) {
      context.handle(
          _deliveryCityMeta,
          deliveryCity.isAcceptableOrUnknown(
              data['delivery_city']!, _deliveryCityMeta));
    }
    if (data.containsKey('tax_pct')) {
      context.handle(_taxPctMeta,
          taxPct.isAcceptableOrUnknown(data['tax_pct']!, _taxPctMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {number};
  @override
  PurchaseOrderEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrderEntity(
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}number'])!,
      supplierId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_id'])!,
      orderDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}order_date'])!,
      expectedDelivery: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}expected_delivery'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by'])!,
      deliveryAddress: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}delivery_address'])!,
      deliveryCity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}delivery_city'])!,
      taxPct: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}tax_pct'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PurchaseOrdersTableTable createAlias(String alias) {
    return $PurchaseOrdersTableTable(attachedDatabase, alias);
  }
}

class PurchaseOrderEntity extends DataClass
    implements Insertable<PurchaseOrderEntity> {
  final String number;
  final String supplierId;
  final DateTime orderDate;
  final DateTime expectedDelivery;
  final String status;
  final String createdBy;
  final String deliveryAddress;
  final String deliveryCity;
  final double taxPct;
  final String notes;
  final DateTime updatedAt;
  const PurchaseOrderEntity(
      {required this.number,
      required this.supplierId,
      required this.orderDate,
      required this.expectedDelivery,
      required this.status,
      required this.createdBy,
      required this.deliveryAddress,
      required this.deliveryCity,
      required this.taxPct,
      required this.notes,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['number'] = Variable<String>(number);
    map['supplier_id'] = Variable<String>(supplierId);
    map['order_date'] = Variable<DateTime>(orderDate);
    map['expected_delivery'] = Variable<DateTime>(expectedDelivery);
    map['status'] = Variable<String>(status);
    map['created_by'] = Variable<String>(createdBy);
    map['delivery_address'] = Variable<String>(deliveryAddress);
    map['delivery_city'] = Variable<String>(deliveryCity);
    map['tax_pct'] = Variable<double>(taxPct);
    map['notes'] = Variable<String>(notes);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PurchaseOrdersTableCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrdersTableCompanion(
      number: Value(number),
      supplierId: Value(supplierId),
      orderDate: Value(orderDate),
      expectedDelivery: Value(expectedDelivery),
      status: Value(status),
      createdBy: Value(createdBy),
      deliveryAddress: Value(deliveryAddress),
      deliveryCity: Value(deliveryCity),
      taxPct: Value(taxPct),
      notes: Value(notes),
      updatedAt: Value(updatedAt),
    );
  }

  factory PurchaseOrderEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrderEntity(
      number: serializer.fromJson<String>(json['number']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      orderDate: serializer.fromJson<DateTime>(json['orderDate']),
      expectedDelivery: serializer.fromJson<DateTime>(json['expectedDelivery']),
      status: serializer.fromJson<String>(json['status']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      deliveryAddress: serializer.fromJson<String>(json['deliveryAddress']),
      deliveryCity: serializer.fromJson<String>(json['deliveryCity']),
      taxPct: serializer.fromJson<double>(json['taxPct']),
      notes: serializer.fromJson<String>(json['notes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'number': serializer.toJson<String>(number),
      'supplierId': serializer.toJson<String>(supplierId),
      'orderDate': serializer.toJson<DateTime>(orderDate),
      'expectedDelivery': serializer.toJson<DateTime>(expectedDelivery),
      'status': serializer.toJson<String>(status),
      'createdBy': serializer.toJson<String>(createdBy),
      'deliveryAddress': serializer.toJson<String>(deliveryAddress),
      'deliveryCity': serializer.toJson<String>(deliveryCity),
      'taxPct': serializer.toJson<double>(taxPct),
      'notes': serializer.toJson<String>(notes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PurchaseOrderEntity copyWith(
          {String? number,
          String? supplierId,
          DateTime? orderDate,
          DateTime? expectedDelivery,
          String? status,
          String? createdBy,
          String? deliveryAddress,
          String? deliveryCity,
          double? taxPct,
          String? notes,
          DateTime? updatedAt}) =>
      PurchaseOrderEntity(
        number: number ?? this.number,
        supplierId: supplierId ?? this.supplierId,
        orderDate: orderDate ?? this.orderDate,
        expectedDelivery: expectedDelivery ?? this.expectedDelivery,
        status: status ?? this.status,
        createdBy: createdBy ?? this.createdBy,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        deliveryCity: deliveryCity ?? this.deliveryCity,
        taxPct: taxPct ?? this.taxPct,
        notes: notes ?? this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PurchaseOrderEntity copyWithCompanion(PurchaseOrdersTableCompanion data) {
    return PurchaseOrderEntity(
      number: data.number.present ? data.number.value : this.number,
      supplierId:
          data.supplierId.present ? data.supplierId.value : this.supplierId,
      orderDate: data.orderDate.present ? data.orderDate.value : this.orderDate,
      expectedDelivery: data.expectedDelivery.present
          ? data.expectedDelivery.value
          : this.expectedDelivery,
      status: data.status.present ? data.status.value : this.status,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deliveryAddress: data.deliveryAddress.present
          ? data.deliveryAddress.value
          : this.deliveryAddress,
      deliveryCity: data.deliveryCity.present
          ? data.deliveryCity.value
          : this.deliveryCity,
      taxPct: data.taxPct.present ? data.taxPct.value : this.taxPct,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderEntity(')
          ..write('number: $number, ')
          ..write('supplierId: $supplierId, ')
          ..write('orderDate: $orderDate, ')
          ..write('expectedDelivery: $expectedDelivery, ')
          ..write('status: $status, ')
          ..write('createdBy: $createdBy, ')
          ..write('deliveryAddress: $deliveryAddress, ')
          ..write('deliveryCity: $deliveryCity, ')
          ..write('taxPct: $taxPct, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      number,
      supplierId,
      orderDate,
      expectedDelivery,
      status,
      createdBy,
      deliveryAddress,
      deliveryCity,
      taxPct,
      notes,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderEntity &&
          other.number == this.number &&
          other.supplierId == this.supplierId &&
          other.orderDate == this.orderDate &&
          other.expectedDelivery == this.expectedDelivery &&
          other.status == this.status &&
          other.createdBy == this.createdBy &&
          other.deliveryAddress == this.deliveryAddress &&
          other.deliveryCity == this.deliveryCity &&
          other.taxPct == this.taxPct &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt);
}

class PurchaseOrdersTableCompanion
    extends UpdateCompanion<PurchaseOrderEntity> {
  final Value<String> number;
  final Value<String> supplierId;
  final Value<DateTime> orderDate;
  final Value<DateTime> expectedDelivery;
  final Value<String> status;
  final Value<String> createdBy;
  final Value<String> deliveryAddress;
  final Value<String> deliveryCity;
  final Value<double> taxPct;
  final Value<String> notes;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PurchaseOrdersTableCompanion({
    this.number = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.orderDate = const Value.absent(),
    this.expectedDelivery = const Value.absent(),
    this.status = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deliveryAddress = const Value.absent(),
    this.deliveryCity = const Value.absent(),
    this.taxPct = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrdersTableCompanion.insert({
    required String number,
    required String supplierId,
    required DateTime orderDate,
    required DateTime expectedDelivery,
    required String status,
    this.createdBy = const Value.absent(),
    this.deliveryAddress = const Value.absent(),
    this.deliveryCity = const Value.absent(),
    this.taxPct = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : number = Value(number),
        supplierId = Value(supplierId),
        orderDate = Value(orderDate),
        expectedDelivery = Value(expectedDelivery),
        status = Value(status);
  static Insertable<PurchaseOrderEntity> custom({
    Expression<String>? number,
    Expression<String>? supplierId,
    Expression<DateTime>? orderDate,
    Expression<DateTime>? expectedDelivery,
    Expression<String>? status,
    Expression<String>? createdBy,
    Expression<String>? deliveryAddress,
    Expression<String>? deliveryCity,
    Expression<double>? taxPct,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (number != null) 'number': number,
      if (supplierId != null) 'supplier_id': supplierId,
      if (orderDate != null) 'order_date': orderDate,
      if (expectedDelivery != null) 'expected_delivery': expectedDelivery,
      if (status != null) 'status': status,
      if (createdBy != null) 'created_by': createdBy,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryCity != null) 'delivery_city': deliveryCity,
      if (taxPct != null) 'tax_pct': taxPct,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrdersTableCompanion copyWith(
      {Value<String>? number,
      Value<String>? supplierId,
      Value<DateTime>? orderDate,
      Value<DateTime>? expectedDelivery,
      Value<String>? status,
      Value<String>? createdBy,
      Value<String>? deliveryAddress,
      Value<String>? deliveryCity,
      Value<double>? taxPct,
      Value<String>? notes,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PurchaseOrdersTableCompanion(
      number: number ?? this.number,
      supplierId: supplierId ?? this.supplierId,
      orderDate: orderDate ?? this.orderDate,
      expectedDelivery: expectedDelivery ?? this.expectedDelivery,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      taxPct: taxPct ?? this.taxPct,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (orderDate.present) {
      map['order_date'] = Variable<DateTime>(orderDate.value);
    }
    if (expectedDelivery.present) {
      map['expected_delivery'] = Variable<DateTime>(expectedDelivery.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deliveryAddress.present) {
      map['delivery_address'] = Variable<String>(deliveryAddress.value);
    }
    if (deliveryCity.present) {
      map['delivery_city'] = Variable<String>(deliveryCity.value);
    }
    if (taxPct.present) {
      map['tax_pct'] = Variable<double>(taxPct.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrdersTableCompanion(')
          ..write('number: $number, ')
          ..write('supplierId: $supplierId, ')
          ..write('orderDate: $orderDate, ')
          ..write('expectedDelivery: $expectedDelivery, ')
          ..write('status: $status, ')
          ..write('createdBy: $createdBy, ')
          ..write('deliveryAddress: $deliveryAddress, ')
          ..write('deliveryCity: $deliveryCity, ')
          ..write('taxPct: $taxPct, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrderLinesTableTable extends PurchaseOrderLinesTable
    with TableInfo<$PurchaseOrderLinesTableTable, PurchaseOrderLineEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrderLinesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _poNumberMeta =
      const VerificationMeta('poNumber');
  @override
  late final GeneratedColumn<String> poNumber = GeneratedColumn<String>(
      'po_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _materialIdMeta =
      const VerificationMeta('materialId');
  @override
  late final GeneratedColumn<String> materialId = GeneratedColumn<String>(
      'material_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _materialNameMeta =
      const VerificationMeta('materialName');
  @override
  late final GeneratedColumn<String> materialName = GeneratedColumn<String>(
      'material_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitCostMeta =
      const VerificationMeta('unitCost');
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
      'unit_cost', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _orderedQtyMeta =
      const VerificationMeta('orderedQty');
  @override
  late final GeneratedColumn<double> orderedQty = GeneratedColumn<double>(
      'ordered_qty', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _receivedQtyMeta =
      const VerificationMeta('receivedQty');
  @override
  late final GeneratedColumn<double> receivedQty = GeneratedColumn<double>(
      'received_qty', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rejectedQtyMeta =
      const VerificationMeta('rejectedQty');
  @override
  late final GeneratedColumn<double> rejectedQty = GeneratedColumn<double>(
      'rejected_qty', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        poNumber,
        materialId,
        materialName,
        code,
        unit,
        unitCost,
        orderedQty,
        receivedQty,
        rejectedQty
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_order_lines_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<PurchaseOrderLineEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('po_number')) {
      context.handle(_poNumberMeta,
          poNumber.isAcceptableOrUnknown(data['po_number']!, _poNumberMeta));
    } else if (isInserting) {
      context.missing(_poNumberMeta);
    }
    if (data.containsKey('material_id')) {
      context.handle(
          _materialIdMeta,
          materialId.isAcceptableOrUnknown(
              data['material_id']!, _materialIdMeta));
    }
    if (data.containsKey('material_name')) {
      context.handle(
          _materialNameMeta,
          materialName.isAcceptableOrUnknown(
              data['material_name']!, _materialNameMeta));
    } else if (isInserting) {
      context.missing(_materialNameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('unit_cost')) {
      context.handle(_unitCostMeta,
          unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta));
    } else if (isInserting) {
      context.missing(_unitCostMeta);
    }
    if (data.containsKey('ordered_qty')) {
      context.handle(
          _orderedQtyMeta,
          orderedQty.isAcceptableOrUnknown(
              data['ordered_qty']!, _orderedQtyMeta));
    } else if (isInserting) {
      context.missing(_orderedQtyMeta);
    }
    if (data.containsKey('received_qty')) {
      context.handle(
          _receivedQtyMeta,
          receivedQty.isAcceptableOrUnknown(
              data['received_qty']!, _receivedQtyMeta));
    }
    if (data.containsKey('rejected_qty')) {
      context.handle(
          _rejectedQtyMeta,
          rejectedQty.isAcceptableOrUnknown(
              data['rejected_qty']!, _rejectedQtyMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrderLineEntity map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrderLineEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      poNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}po_number'])!,
      materialId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material_id']),
      materialName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material_name'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      unitCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}unit_cost'])!,
      orderedQty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ordered_qty'])!,
      receivedQty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}received_qty'])!,
      rejectedQty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rejected_qty'])!,
    );
  }

  @override
  $PurchaseOrderLinesTableTable createAlias(String alias) {
    return $PurchaseOrderLinesTableTable(attachedDatabase, alias);
  }
}

class PurchaseOrderLineEntity extends DataClass
    implements Insertable<PurchaseOrderLineEntity> {
  final int id;
  final String poNumber;
  final String? materialId;
  final String materialName;
  final String code;
  final String unit;
  final double unitCost;
  final double orderedQty;
  final double receivedQty;
  final double rejectedQty;
  const PurchaseOrderLineEntity(
      {required this.id,
      required this.poNumber,
      this.materialId,
      required this.materialName,
      required this.code,
      required this.unit,
      required this.unitCost,
      required this.orderedQty,
      required this.receivedQty,
      required this.rejectedQty});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['po_number'] = Variable<String>(poNumber);
    if (!nullToAbsent || materialId != null) {
      map['material_id'] = Variable<String>(materialId);
    }
    map['material_name'] = Variable<String>(materialName);
    map['code'] = Variable<String>(code);
    map['unit'] = Variable<String>(unit);
    map['unit_cost'] = Variable<double>(unitCost);
    map['ordered_qty'] = Variable<double>(orderedQty);
    map['received_qty'] = Variable<double>(receivedQty);
    map['rejected_qty'] = Variable<double>(rejectedQty);
    return map;
  }

  PurchaseOrderLinesTableCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrderLinesTableCompanion(
      id: Value(id),
      poNumber: Value(poNumber),
      materialId: materialId == null && nullToAbsent
          ? const Value.absent()
          : Value(materialId),
      materialName: Value(materialName),
      code: Value(code),
      unit: Value(unit),
      unitCost: Value(unitCost),
      orderedQty: Value(orderedQty),
      receivedQty: Value(receivedQty),
      rejectedQty: Value(rejectedQty),
    );
  }

  factory PurchaseOrderLineEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrderLineEntity(
      id: serializer.fromJson<int>(json['id']),
      poNumber: serializer.fromJson<String>(json['poNumber']),
      materialId: serializer.fromJson<String?>(json['materialId']),
      materialName: serializer.fromJson<String>(json['materialName']),
      code: serializer.fromJson<String>(json['code']),
      unit: serializer.fromJson<String>(json['unit']),
      unitCost: serializer.fromJson<double>(json['unitCost']),
      orderedQty: serializer.fromJson<double>(json['orderedQty']),
      receivedQty: serializer.fromJson<double>(json['receivedQty']),
      rejectedQty: serializer.fromJson<double>(json['rejectedQty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'poNumber': serializer.toJson<String>(poNumber),
      'materialId': serializer.toJson<String?>(materialId),
      'materialName': serializer.toJson<String>(materialName),
      'code': serializer.toJson<String>(code),
      'unit': serializer.toJson<String>(unit),
      'unitCost': serializer.toJson<double>(unitCost),
      'orderedQty': serializer.toJson<double>(orderedQty),
      'receivedQty': serializer.toJson<double>(receivedQty),
      'rejectedQty': serializer.toJson<double>(rejectedQty),
    };
  }

  PurchaseOrderLineEntity copyWith(
          {int? id,
          String? poNumber,
          Value<String?> materialId = const Value.absent(),
          String? materialName,
          String? code,
          String? unit,
          double? unitCost,
          double? orderedQty,
          double? receivedQty,
          double? rejectedQty}) =>
      PurchaseOrderLineEntity(
        id: id ?? this.id,
        poNumber: poNumber ?? this.poNumber,
        materialId: materialId.present ? materialId.value : this.materialId,
        materialName: materialName ?? this.materialName,
        code: code ?? this.code,
        unit: unit ?? this.unit,
        unitCost: unitCost ?? this.unitCost,
        orderedQty: orderedQty ?? this.orderedQty,
        receivedQty: receivedQty ?? this.receivedQty,
        rejectedQty: rejectedQty ?? this.rejectedQty,
      );
  PurchaseOrderLineEntity copyWithCompanion(
      PurchaseOrderLinesTableCompanion data) {
    return PurchaseOrderLineEntity(
      id: data.id.present ? data.id.value : this.id,
      poNumber: data.poNumber.present ? data.poNumber.value : this.poNumber,
      materialId:
          data.materialId.present ? data.materialId.value : this.materialId,
      materialName: data.materialName.present
          ? data.materialName.value
          : this.materialName,
      code: data.code.present ? data.code.value : this.code,
      unit: data.unit.present ? data.unit.value : this.unit,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      orderedQty:
          data.orderedQty.present ? data.orderedQty.value : this.orderedQty,
      receivedQty:
          data.receivedQty.present ? data.receivedQty.value : this.receivedQty,
      rejectedQty:
          data.rejectedQty.present ? data.rejectedQty.value : this.rejectedQty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderLineEntity(')
          ..write('id: $id, ')
          ..write('poNumber: $poNumber, ')
          ..write('materialId: $materialId, ')
          ..write('materialName: $materialName, ')
          ..write('code: $code, ')
          ..write('unit: $unit, ')
          ..write('unitCost: $unitCost, ')
          ..write('orderedQty: $orderedQty, ')
          ..write('receivedQty: $receivedQty, ')
          ..write('rejectedQty: $rejectedQty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, poNumber, materialId, materialName, code,
      unit, unitCost, orderedQty, receivedQty, rejectedQty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderLineEntity &&
          other.id == this.id &&
          other.poNumber == this.poNumber &&
          other.materialId == this.materialId &&
          other.materialName == this.materialName &&
          other.code == this.code &&
          other.unit == this.unit &&
          other.unitCost == this.unitCost &&
          other.orderedQty == this.orderedQty &&
          other.receivedQty == this.receivedQty &&
          other.rejectedQty == this.rejectedQty);
}

class PurchaseOrderLinesTableCompanion
    extends UpdateCompanion<PurchaseOrderLineEntity> {
  final Value<int> id;
  final Value<String> poNumber;
  final Value<String?> materialId;
  final Value<String> materialName;
  final Value<String> code;
  final Value<String> unit;
  final Value<double> unitCost;
  final Value<double> orderedQty;
  final Value<double> receivedQty;
  final Value<double> rejectedQty;
  const PurchaseOrderLinesTableCompanion({
    this.id = const Value.absent(),
    this.poNumber = const Value.absent(),
    this.materialId = const Value.absent(),
    this.materialName = const Value.absent(),
    this.code = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.orderedQty = const Value.absent(),
    this.receivedQty = const Value.absent(),
    this.rejectedQty = const Value.absent(),
  });
  PurchaseOrderLinesTableCompanion.insert({
    this.id = const Value.absent(),
    required String poNumber,
    this.materialId = const Value.absent(),
    required String materialName,
    this.code = const Value.absent(),
    required String unit,
    required double unitCost,
    required double orderedQty,
    this.receivedQty = const Value.absent(),
    this.rejectedQty = const Value.absent(),
  })  : poNumber = Value(poNumber),
        materialName = Value(materialName),
        unit = Value(unit),
        unitCost = Value(unitCost),
        orderedQty = Value(orderedQty);
  static Insertable<PurchaseOrderLineEntity> custom({
    Expression<int>? id,
    Expression<String>? poNumber,
    Expression<String>? materialId,
    Expression<String>? materialName,
    Expression<String>? code,
    Expression<String>? unit,
    Expression<double>? unitCost,
    Expression<double>? orderedQty,
    Expression<double>? receivedQty,
    Expression<double>? rejectedQty,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poNumber != null) 'po_number': poNumber,
      if (materialId != null) 'material_id': materialId,
      if (materialName != null) 'material_name': materialName,
      if (code != null) 'code': code,
      if (unit != null) 'unit': unit,
      if (unitCost != null) 'unit_cost': unitCost,
      if (orderedQty != null) 'ordered_qty': orderedQty,
      if (receivedQty != null) 'received_qty': receivedQty,
      if (rejectedQty != null) 'rejected_qty': rejectedQty,
    });
  }

  PurchaseOrderLinesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? poNumber,
      Value<String?>? materialId,
      Value<String>? materialName,
      Value<String>? code,
      Value<String>? unit,
      Value<double>? unitCost,
      Value<double>? orderedQty,
      Value<double>? receivedQty,
      Value<double>? rejectedQty}) {
    return PurchaseOrderLinesTableCompanion(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      code: code ?? this.code,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      orderedQty: orderedQty ?? this.orderedQty,
      receivedQty: receivedQty ?? this.receivedQty,
      rejectedQty: rejectedQty ?? this.rejectedQty,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (poNumber.present) {
      map['po_number'] = Variable<String>(poNumber.value);
    }
    if (materialId.present) {
      map['material_id'] = Variable<String>(materialId.value);
    }
    if (materialName.present) {
      map['material_name'] = Variable<String>(materialName.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (orderedQty.present) {
      map['ordered_qty'] = Variable<double>(orderedQty.value);
    }
    if (receivedQty.present) {
      map['received_qty'] = Variable<double>(receivedQty.value);
    }
    if (rejectedQty.present) {
      map['rejected_qty'] = Variable<double>(rejectedQty.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderLinesTableCompanion(')
          ..write('id: $id, ')
          ..write('poNumber: $poNumber, ')
          ..write('materialId: $materialId, ')
          ..write('materialName: $materialName, ')
          ..write('code: $code, ')
          ..write('unit: $unit, ')
          ..write('unitCost: $unitCost, ')
          ..write('orderedQty: $orderedQty, ')
          ..write('receivedQty: $receivedQty, ')
          ..write('rejectedQty: $rejectedQty')
          ..write(')'))
        .toString();
  }
}

class $GoodsReceiptsTableTable extends GoodsReceiptsTable
    with TableInfo<$GoodsReceiptsTableTable, GoodsReceiptEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoodsReceiptsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _poNumberMeta =
      const VerificationMeta('poNumber');
  @override
  late final GeneratedColumn<String> poNumber = GeneratedColumn<String>(
      'po_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _subtotalMeta =
      const VerificationMeta('subtotal');
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
      'subtotal', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<double> tax = GeneratedColumn<double>(
      'tax', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
      'total', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [id, poNumber, receivedAt, subtotal, tax, total, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goods_receipts_table';
  @override
  VerificationContext validateIntegrity(Insertable<GoodsReceiptEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('po_number')) {
      context.handle(_poNumberMeta,
          poNumber.isAcceptableOrUnknown(data['po_number']!, _poNumberMeta));
    } else if (isInserting) {
      context.missing(_poNumberMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(_subtotalMeta,
          subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta));
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('tax')) {
      context.handle(
          _taxMeta, tax.isAcceptableOrUnknown(data['tax']!, _taxMeta));
    } else if (isInserting) {
      context.missing(_taxMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
          _totalMeta, total.isAcceptableOrUnknown(data['total']!, _totalMeta));
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoodsReceiptEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoodsReceiptEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      poNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}po_number'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      subtotal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}subtotal'])!,
      tax: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}tax'])!,
      total: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $GoodsReceiptsTableTable createAlias(String alias) {
    return $GoodsReceiptsTableTable(attachedDatabase, alias);
  }
}

class GoodsReceiptEntity extends DataClass
    implements Insertable<GoodsReceiptEntity> {
  final String id;
  final String poNumber;
  final DateTime receivedAt;
  final double subtotal;
  final double tax;
  final double total;
  final String notes;
  const GoodsReceiptEntity(
      {required this.id,
      required this.poNumber,
      required this.receivedAt,
      required this.subtotal,
      required this.tax,
      required this.total,
      required this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['po_number'] = Variable<String>(poNumber);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['subtotal'] = Variable<double>(subtotal);
    map['tax'] = Variable<double>(tax);
    map['total'] = Variable<double>(total);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  GoodsReceiptsTableCompanion toCompanion(bool nullToAbsent) {
    return GoodsReceiptsTableCompanion(
      id: Value(id),
      poNumber: Value(poNumber),
      receivedAt: Value(receivedAt),
      subtotal: Value(subtotal),
      tax: Value(tax),
      total: Value(total),
      notes: Value(notes),
    );
  }

  factory GoodsReceiptEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoodsReceiptEntity(
      id: serializer.fromJson<String>(json['id']),
      poNumber: serializer.fromJson<String>(json['poNumber']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      tax: serializer.fromJson<double>(json['tax']),
      total: serializer.fromJson<double>(json['total']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poNumber': serializer.toJson<String>(poNumber),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'subtotal': serializer.toJson<double>(subtotal),
      'tax': serializer.toJson<double>(tax),
      'total': serializer.toJson<double>(total),
      'notes': serializer.toJson<String>(notes),
    };
  }

  GoodsReceiptEntity copyWith(
          {String? id,
          String? poNumber,
          DateTime? receivedAt,
          double? subtotal,
          double? tax,
          double? total,
          String? notes}) =>
      GoodsReceiptEntity(
        id: id ?? this.id,
        poNumber: poNumber ?? this.poNumber,
        receivedAt: receivedAt ?? this.receivedAt,
        subtotal: subtotal ?? this.subtotal,
        tax: tax ?? this.tax,
        total: total ?? this.total,
        notes: notes ?? this.notes,
      );
  GoodsReceiptEntity copyWithCompanion(GoodsReceiptsTableCompanion data) {
    return GoodsReceiptEntity(
      id: data.id.present ? data.id.value : this.id,
      poNumber: data.poNumber.present ? data.poNumber.value : this.poNumber,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      tax: data.tax.present ? data.tax.value : this.tax,
      total: data.total.present ? data.total.value : this.total,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoodsReceiptEntity(')
          ..write('id: $id, ')
          ..write('poNumber: $poNumber, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('subtotal: $subtotal, ')
          ..write('tax: $tax, ')
          ..write('total: $total, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, poNumber, receivedAt, subtotal, tax, total, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoodsReceiptEntity &&
          other.id == this.id &&
          other.poNumber == this.poNumber &&
          other.receivedAt == this.receivedAt &&
          other.subtotal == this.subtotal &&
          other.tax == this.tax &&
          other.total == this.total &&
          other.notes == this.notes);
}

class GoodsReceiptsTableCompanion extends UpdateCompanion<GoodsReceiptEntity> {
  final Value<String> id;
  final Value<String> poNumber;
  final Value<DateTime> receivedAt;
  final Value<double> subtotal;
  final Value<double> tax;
  final Value<double> total;
  final Value<String> notes;
  final Value<int> rowid;
  const GoodsReceiptsTableCompanion({
    this.id = const Value.absent(),
    this.poNumber = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.tax = const Value.absent(),
    this.total = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoodsReceiptsTableCompanion.insert({
    required String id,
    required String poNumber,
    required DateTime receivedAt,
    required double subtotal,
    required double tax,
    required double total,
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        poNumber = Value(poNumber),
        receivedAt = Value(receivedAt),
        subtotal = Value(subtotal),
        tax = Value(tax),
        total = Value(total);
  static Insertable<GoodsReceiptEntity> custom({
    Expression<String>? id,
    Expression<String>? poNumber,
    Expression<DateTime>? receivedAt,
    Expression<double>? subtotal,
    Expression<double>? tax,
    Expression<double>? total,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poNumber != null) 'po_number': poNumber,
      if (receivedAt != null) 'received_at': receivedAt,
      if (subtotal != null) 'subtotal': subtotal,
      if (tax != null) 'tax': tax,
      if (total != null) 'total': total,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoodsReceiptsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? poNumber,
      Value<DateTime>? receivedAt,
      Value<double>? subtotal,
      Value<double>? tax,
      Value<double>? total,
      Value<String>? notes,
      Value<int>? rowid}) {
    return GoodsReceiptsTableCompanion(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      receivedAt: receivedAt ?? this.receivedAt,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poNumber.present) {
      map['po_number'] = Variable<String>(poNumber.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (tax.present) {
      map['tax'] = Variable<double>(tax.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoodsReceiptsTableCompanion(')
          ..write('id: $id, ')
          ..write('poNumber: $poNumber, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('subtotal: $subtotal, ')
          ..write('tax: $tax, ')
          ..write('total: $total, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTableTable extends StockMovementsTable
    with TableInfo<$StockMovementsTableTable, StockMovementEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _materialIdMeta =
      const VerificationMeta('materialId');
  @override
  late final GeneratedColumn<String> materialId = GeneratedColumn<String>(
      'material_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qtyDeltaMeta =
      const VerificationMeta('qtyDelta');
  @override
  late final GeneratedColumn<double> qtyDelta = GeneratedColumn<double>(
      'qty_delta', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _referenceMeta =
      const VerificationMeta('reference');
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
      'reference', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _unitCostMeta =
      const VerificationMeta('unitCost');
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
      'unit_cost', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, materialId, qtyDelta, reason, reference, unitCost, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<StockMovementEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('material_id')) {
      context.handle(
          _materialIdMeta,
          materialId.isAcceptableOrUnknown(
              data['material_id']!, _materialIdMeta));
    } else if (isInserting) {
      context.missing(_materialIdMeta);
    }
    if (data.containsKey('qty_delta')) {
      context.handle(_qtyDeltaMeta,
          qtyDelta.isAcceptableOrUnknown(data['qty_delta']!, _qtyDeltaMeta));
    } else if (isInserting) {
      context.missing(_qtyDeltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(_referenceMeta,
          reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta));
    }
    if (data.containsKey('unit_cost')) {
      context.handle(_unitCostMeta,
          unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovementEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovementEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      materialId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material_id'])!,
      qtyDelta: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qty_delta'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference'])!,
      unitCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}unit_cost']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $StockMovementsTableTable createAlias(String alias) {
    return $StockMovementsTableTable(attachedDatabase, alias);
  }
}

class StockMovementEntity extends DataClass
    implements Insertable<StockMovementEntity> {
  final int id;
  final String materialId;
  final double qtyDelta;
  final String reason;
  final String reference;
  final double? unitCost;
  final DateTime createdAt;
  const StockMovementEntity(
      {required this.id,
      required this.materialId,
      required this.qtyDelta,
      required this.reason,
      required this.reference,
      this.unitCost,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['material_id'] = Variable<String>(materialId);
    map['qty_delta'] = Variable<double>(qtyDelta);
    map['reason'] = Variable<String>(reason);
    map['reference'] = Variable<String>(reference);
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<double>(unitCost);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StockMovementsTableCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsTableCompanion(
      id: Value(id),
      materialId: Value(materialId),
      qtyDelta: Value(qtyDelta),
      reason: Value(reason),
      reference: Value(reference),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
      createdAt: Value(createdAt),
    );
  }

  factory StockMovementEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovementEntity(
      id: serializer.fromJson<int>(json['id']),
      materialId: serializer.fromJson<String>(json['materialId']),
      qtyDelta: serializer.fromJson<double>(json['qtyDelta']),
      reason: serializer.fromJson<String>(json['reason']),
      reference: serializer.fromJson<String>(json['reference']),
      unitCost: serializer.fromJson<double?>(json['unitCost']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'materialId': serializer.toJson<String>(materialId),
      'qtyDelta': serializer.toJson<double>(qtyDelta),
      'reason': serializer.toJson<String>(reason),
      'reference': serializer.toJson<String>(reference),
      'unitCost': serializer.toJson<double?>(unitCost),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StockMovementEntity copyWith(
          {int? id,
          String? materialId,
          double? qtyDelta,
          String? reason,
          String? reference,
          Value<double?> unitCost = const Value.absent(),
          DateTime? createdAt}) =>
      StockMovementEntity(
        id: id ?? this.id,
        materialId: materialId ?? this.materialId,
        qtyDelta: qtyDelta ?? this.qtyDelta,
        reason: reason ?? this.reason,
        reference: reference ?? this.reference,
        unitCost: unitCost.present ? unitCost.value : this.unitCost,
        createdAt: createdAt ?? this.createdAt,
      );
  StockMovementEntity copyWithCompanion(StockMovementsTableCompanion data) {
    return StockMovementEntity(
      id: data.id.present ? data.id.value : this.id,
      materialId:
          data.materialId.present ? data.materialId.value : this.materialId,
      qtyDelta: data.qtyDelta.present ? data.qtyDelta.value : this.qtyDelta,
      reason: data.reason.present ? data.reason.value : this.reason,
      reference: data.reference.present ? data.reference.value : this.reference,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementEntity(')
          ..write('id: $id, ')
          ..write('materialId: $materialId, ')
          ..write('qtyDelta: $qtyDelta, ')
          ..write('reason: $reason, ')
          ..write('reference: $reference, ')
          ..write('unitCost: $unitCost, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, materialId, qtyDelta, reason, reference, unitCost, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovementEntity &&
          other.id == this.id &&
          other.materialId == this.materialId &&
          other.qtyDelta == this.qtyDelta &&
          other.reason == this.reason &&
          other.reference == this.reference &&
          other.unitCost == this.unitCost &&
          other.createdAt == this.createdAt);
}

class StockMovementsTableCompanion
    extends UpdateCompanion<StockMovementEntity> {
  final Value<int> id;
  final Value<String> materialId;
  final Value<double> qtyDelta;
  final Value<String> reason;
  final Value<String> reference;
  final Value<double?> unitCost;
  final Value<DateTime> createdAt;
  const StockMovementsTableCompanion({
    this.id = const Value.absent(),
    this.materialId = const Value.absent(),
    this.qtyDelta = const Value.absent(),
    this.reason = const Value.absent(),
    this.reference = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StockMovementsTableCompanion.insert({
    this.id = const Value.absent(),
    required String materialId,
    required double qtyDelta,
    required String reason,
    this.reference = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : materialId = Value(materialId),
        qtyDelta = Value(qtyDelta),
        reason = Value(reason);
  static Insertable<StockMovementEntity> custom({
    Expression<int>? id,
    Expression<String>? materialId,
    Expression<double>? qtyDelta,
    Expression<String>? reason,
    Expression<String>? reference,
    Expression<double>? unitCost,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (materialId != null) 'material_id': materialId,
      if (qtyDelta != null) 'qty_delta': qtyDelta,
      if (reason != null) 'reason': reason,
      if (reference != null) 'reference': reference,
      if (unitCost != null) 'unit_cost': unitCost,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StockMovementsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? materialId,
      Value<double>? qtyDelta,
      Value<String>? reason,
      Value<String>? reference,
      Value<double?>? unitCost,
      Value<DateTime>? createdAt}) {
    return StockMovementsTableCompanion(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      qtyDelta: qtyDelta ?? this.qtyDelta,
      reason: reason ?? this.reason,
      reference: reference ?? this.reference,
      unitCost: unitCost ?? this.unitCost,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (materialId.present) {
      map['material_id'] = Variable<String>(materialId.value);
    }
    if (qtyDelta.present) {
      map['qty_delta'] = Variable<double>(qtyDelta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsTableCompanion(')
          ..write('id: $id, ')
          ..write('materialId: $materialId, ')
          ..write('qtyDelta: $qtyDelta, ')
          ..write('reason: $reason, ')
          ..write('reference: $reference, ')
          ..write('unitCost: $unitCost, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OffersTableTable extends OffersTable
    with TableInfo<$OffersTableTable, OfferEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OffersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _campaignTypeMeta =
      const VerificationMeta('campaignType');
  @override
  late final GeneratedColumn<String> campaignType = GeneratedColumn<String>(
      'campaign_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _discountRuleMeta =
      const VerificationMeta('discountRule');
  @override
  late final GeneratedColumn<String> discountRule = GeneratedColumn<String>(
      'discount_rule', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _minOrderMeta =
      const VerificationMeta('minOrder');
  @override
  late final GeneratedColumn<double> minOrder = GeneratedColumn<double>(
      'min_order', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _maxDiscountMeta =
      const VerificationMeta('maxDiscount');
  @override
  late final GeneratedColumn<double> maxDiscount = GeneratedColumn<double>(
      'max_discount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _channelsMeta =
      const VerificationMeta('channels');
  @override
  late final GeneratedColumn<String> channels = GeneratedColumn<String>(
      'channels', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _linkedItemsMeta =
      const VerificationMeta('linkedItems');
  @override
  late final GeneratedColumn<String> linkedItems = GeneratedColumn<String>(
      'linked_items', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usageCountMeta =
      const VerificationMeta('usageCount');
  @override
  late final GeneratedColumn<int> usageCount = GeneratedColumn<int>(
      'usage_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        code,
        campaignType,
        discountRule,
        minOrder,
        maxDiscount,
        startDate,
        endDate,
        channels,
        linkedItems,
        status,
        usageCount,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offers_table';
  @override
  VerificationContext validateIntegrity(Insertable<OfferEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('campaign_type')) {
      context.handle(
          _campaignTypeMeta,
          campaignType.isAcceptableOrUnknown(
              data['campaign_type']!, _campaignTypeMeta));
    } else if (isInserting) {
      context.missing(_campaignTypeMeta);
    }
    if (data.containsKey('discount_rule')) {
      context.handle(
          _discountRuleMeta,
          discountRule.isAcceptableOrUnknown(
              data['discount_rule']!, _discountRuleMeta));
    } else if (isInserting) {
      context.missing(_discountRuleMeta);
    }
    if (data.containsKey('min_order')) {
      context.handle(_minOrderMeta,
          minOrder.isAcceptableOrUnknown(data['min_order']!, _minOrderMeta));
    }
    if (data.containsKey('max_discount')) {
      context.handle(
          _maxDiscountMeta,
          maxDiscount.isAcceptableOrUnknown(
              data['max_discount']!, _maxDiscountMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('channels')) {
      context.handle(_channelsMeta,
          channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta));
    }
    if (data.containsKey('linked_items')) {
      context.handle(
          _linkedItemsMeta,
          linkedItems.isAcceptableOrUnknown(
              data['linked_items']!, _linkedItemsMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('usage_count')) {
      context.handle(
          _usageCountMeta,
          usageCount.isAcceptableOrUnknown(
              data['usage_count']!, _usageCountMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfferEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfferEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      campaignType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}campaign_type'])!,
      discountRule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}discount_rule'])!,
      minOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}min_order'])!,
      maxDiscount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}max_discount'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      channels: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channels'])!,
      linkedItems: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}linked_items'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      usageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}usage_count'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $OffersTableTable createAlias(String alias) {
    return $OffersTableTable(attachedDatabase, alias);
  }
}

class OfferEntity extends DataClass implements Insertable<OfferEntity> {
  final String id;
  final String title;
  final String code;
  final String campaignType;
  final String discountRule;
  final double minOrder;
  final double maxDiscount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String channels;
  final String linkedItems;
  final String status;
  final int usageCount;
  final DateTime updatedAt;
  const OfferEntity(
      {required this.id,
      required this.title,
      required this.code,
      required this.campaignType,
      required this.discountRule,
      required this.minOrder,
      required this.maxDiscount,
      this.startDate,
      this.endDate,
      required this.channels,
      required this.linkedItems,
      required this.status,
      required this.usageCount,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['code'] = Variable<String>(code);
    map['campaign_type'] = Variable<String>(campaignType);
    map['discount_rule'] = Variable<String>(discountRule);
    map['min_order'] = Variable<double>(minOrder);
    map['max_discount'] = Variable<double>(maxDiscount);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['channels'] = Variable<String>(channels);
    map['linked_items'] = Variable<String>(linkedItems);
    map['status'] = Variable<String>(status);
    map['usage_count'] = Variable<int>(usageCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OffersTableCompanion toCompanion(bool nullToAbsent) {
    return OffersTableCompanion(
      id: Value(id),
      title: Value(title),
      code: Value(code),
      campaignType: Value(campaignType),
      discountRule: Value(discountRule),
      minOrder: Value(minOrder),
      maxDiscount: Value(maxDiscount),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      channels: Value(channels),
      linkedItems: Value(linkedItems),
      status: Value(status),
      usageCount: Value(usageCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory OfferEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfferEntity(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      code: serializer.fromJson<String>(json['code']),
      campaignType: serializer.fromJson<String>(json['campaignType']),
      discountRule: serializer.fromJson<String>(json['discountRule']),
      minOrder: serializer.fromJson<double>(json['minOrder']),
      maxDiscount: serializer.fromJson<double>(json['maxDiscount']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      channels: serializer.fromJson<String>(json['channels']),
      linkedItems: serializer.fromJson<String>(json['linkedItems']),
      status: serializer.fromJson<String>(json['status']),
      usageCount: serializer.fromJson<int>(json['usageCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'code': serializer.toJson<String>(code),
      'campaignType': serializer.toJson<String>(campaignType),
      'discountRule': serializer.toJson<String>(discountRule),
      'minOrder': serializer.toJson<double>(minOrder),
      'maxDiscount': serializer.toJson<double>(maxDiscount),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'channels': serializer.toJson<String>(channels),
      'linkedItems': serializer.toJson<String>(linkedItems),
      'status': serializer.toJson<String>(status),
      'usageCount': serializer.toJson<int>(usageCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OfferEntity copyWith(
          {String? id,
          String? title,
          String? code,
          String? campaignType,
          String? discountRule,
          double? minOrder,
          double? maxDiscount,
          Value<DateTime?> startDate = const Value.absent(),
          Value<DateTime?> endDate = const Value.absent(),
          String? channels,
          String? linkedItems,
          String? status,
          int? usageCount,
          DateTime? updatedAt}) =>
      OfferEntity(
        id: id ?? this.id,
        title: title ?? this.title,
        code: code ?? this.code,
        campaignType: campaignType ?? this.campaignType,
        discountRule: discountRule ?? this.discountRule,
        minOrder: minOrder ?? this.minOrder,
        maxDiscount: maxDiscount ?? this.maxDiscount,
        startDate: startDate.present ? startDate.value : this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        channels: channels ?? this.channels,
        linkedItems: linkedItems ?? this.linkedItems,
        status: status ?? this.status,
        usageCount: usageCount ?? this.usageCount,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  OfferEntity copyWithCompanion(OffersTableCompanion data) {
    return OfferEntity(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      code: data.code.present ? data.code.value : this.code,
      campaignType: data.campaignType.present
          ? data.campaignType.value
          : this.campaignType,
      discountRule: data.discountRule.present
          ? data.discountRule.value
          : this.discountRule,
      minOrder: data.minOrder.present ? data.minOrder.value : this.minOrder,
      maxDiscount:
          data.maxDiscount.present ? data.maxDiscount.value : this.maxDiscount,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      channels: data.channels.present ? data.channels.value : this.channels,
      linkedItems:
          data.linkedItems.present ? data.linkedItems.value : this.linkedItems,
      status: data.status.present ? data.status.value : this.status,
      usageCount:
          data.usageCount.present ? data.usageCount.value : this.usageCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfferEntity(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('code: $code, ')
          ..write('campaignType: $campaignType, ')
          ..write('discountRule: $discountRule, ')
          ..write('minOrder: $minOrder, ')
          ..write('maxDiscount: $maxDiscount, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('channels: $channels, ')
          ..write('linkedItems: $linkedItems, ')
          ..write('status: $status, ')
          ..write('usageCount: $usageCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      code,
      campaignType,
      discountRule,
      minOrder,
      maxDiscount,
      startDate,
      endDate,
      channels,
      linkedItems,
      status,
      usageCount,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfferEntity &&
          other.id == this.id &&
          other.title == this.title &&
          other.code == this.code &&
          other.campaignType == this.campaignType &&
          other.discountRule == this.discountRule &&
          other.minOrder == this.minOrder &&
          other.maxDiscount == this.maxDiscount &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.channels == this.channels &&
          other.linkedItems == this.linkedItems &&
          other.status == this.status &&
          other.usageCount == this.usageCount &&
          other.updatedAt == this.updatedAt);
}

class OffersTableCompanion extends UpdateCompanion<OfferEntity> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> code;
  final Value<String> campaignType;
  final Value<String> discountRule;
  final Value<double> minOrder;
  final Value<double> maxDiscount;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<String> channels;
  final Value<String> linkedItems;
  final Value<String> status;
  final Value<int> usageCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OffersTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.code = const Value.absent(),
    this.campaignType = const Value.absent(),
    this.discountRule = const Value.absent(),
    this.minOrder = const Value.absent(),
    this.maxDiscount = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.channels = const Value.absent(),
    this.linkedItems = const Value.absent(),
    this.status = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OffersTableCompanion.insert({
    required String id,
    required String title,
    required String code,
    required String campaignType,
    required String discountRule,
    this.minOrder = const Value.absent(),
    this.maxDiscount = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.channels = const Value.absent(),
    this.linkedItems = const Value.absent(),
    required String status,
    this.usageCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        code = Value(code),
        campaignType = Value(campaignType),
        discountRule = Value(discountRule),
        status = Value(status);
  static Insertable<OfferEntity> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? code,
    Expression<String>? campaignType,
    Expression<String>? discountRule,
    Expression<double>? minOrder,
    Expression<double>? maxDiscount,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? channels,
    Expression<String>? linkedItems,
    Expression<String>? status,
    Expression<int>? usageCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (code != null) 'code': code,
      if (campaignType != null) 'campaign_type': campaignType,
      if (discountRule != null) 'discount_rule': discountRule,
      if (minOrder != null) 'min_order': minOrder,
      if (maxDiscount != null) 'max_discount': maxDiscount,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (channels != null) 'channels': channels,
      if (linkedItems != null) 'linked_items': linkedItems,
      if (status != null) 'status': status,
      if (usageCount != null) 'usage_count': usageCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OffersTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? code,
      Value<String>? campaignType,
      Value<String>? discountRule,
      Value<double>? minOrder,
      Value<double>? maxDiscount,
      Value<DateTime?>? startDate,
      Value<DateTime?>? endDate,
      Value<String>? channels,
      Value<String>? linkedItems,
      Value<String>? status,
      Value<int>? usageCount,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return OffersTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      code: code ?? this.code,
      campaignType: campaignType ?? this.campaignType,
      discountRule: discountRule ?? this.discountRule,
      minOrder: minOrder ?? this.minOrder,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      channels: channels ?? this.channels,
      linkedItems: linkedItems ?? this.linkedItems,
      status: status ?? this.status,
      usageCount: usageCount ?? this.usageCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (campaignType.present) {
      map['campaign_type'] = Variable<String>(campaignType.value);
    }
    if (discountRule.present) {
      map['discount_rule'] = Variable<String>(discountRule.value);
    }
    if (minOrder.present) {
      map['min_order'] = Variable<double>(minOrder.value);
    }
    if (maxDiscount.present) {
      map['max_discount'] = Variable<double>(maxDiscount.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (channels.present) {
      map['channels'] = Variable<String>(channels.value);
    }
    if (linkedItems.present) {
      map['linked_items'] = Variable<String>(linkedItems.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (usageCount.present) {
      map['usage_count'] = Variable<int>(usageCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OffersTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('code: $code, ')
          ..write('campaignType: $campaignType, ')
          ..write('discountRule: $discountRule, ')
          ..write('minOrder: $minOrder, ')
          ..write('maxDiscount: $maxDiscount, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('channels: $channels, ')
          ..write('linkedItems: $linkedItems, ')
          ..write('status: $status, ')
          ..write('usageCount: $usageCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaAssetsTableTable extends MediaAssetsTable
    with TableInfo<$MediaAssetsTableTable, MediaAssetEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaAssetsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileTypeMeta =
      const VerificationMeta('fileType');
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
      'file_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
      'folder', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usageLabelMeta =
      const VerificationMeta('usageLabel');
  @override
  late final GeneratedColumn<String> usageLabel = GeneratedColumn<String>(
      'usage_label', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
      'bytes', aliasedName, true,
      type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        fileName,
        fileType,
        sizeBytes,
        folder,
        usageLabel,
        imageUrl,
        bytes,
        archived,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_assets_table';
  @override
  VerificationContext validateIntegrity(Insertable<MediaAssetEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_type')) {
      context.handle(_fileTypeMeta,
          fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta));
    } else if (isInserting) {
      context.missing(_fileTypeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('folder')) {
      context.handle(_folderMeta,
          folder.isAcceptableOrUnknown(data['folder']!, _folderMeta));
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('usage_label')) {
      context.handle(
          _usageLabelMeta,
          usageLabel.isAcceptableOrUnknown(
              data['usage_label']!, _usageLabelMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaAssetEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaAssetEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      fileType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_type'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      folder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}folder'])!,
      usageLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}usage_label'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      bytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}bytes']),
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MediaAssetsTableTable createAlias(String alias) {
    return $MediaAssetsTableTable(attachedDatabase, alias);
  }
}

class MediaAssetEntity extends DataClass
    implements Insertable<MediaAssetEntity> {
  final String id;
  final String fileName;
  final String fileType;
  final int sizeBytes;
  final String folder;
  final String usageLabel;

  /// Remote image for seeded assets; null for uploaded files.
  final String? imageUrl;

  /// Uploaded file content (kept small — the upload path caps size).
  final Uint8List? bytes;
  final bool archived;
  final DateTime createdAt;
  const MediaAssetEntity(
      {required this.id,
      required this.fileName,
      required this.fileType,
      required this.sizeBytes,
      required this.folder,
      required this.usageLabel,
      this.imageUrl,
      this.bytes,
      required this.archived,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_name'] = Variable<String>(fileName);
    map['file_type'] = Variable<String>(fileType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['folder'] = Variable<String>(folder);
    map['usage_label'] = Variable<String>(usageLabel);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<Uint8List>(bytes);
    }
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MediaAssetsTableCompanion toCompanion(bool nullToAbsent) {
    return MediaAssetsTableCompanion(
      id: Value(id),
      fileName: Value(fileName),
      fileType: Value(fileType),
      sizeBytes: Value(sizeBytes),
      folder: Value(folder),
      usageLabel: Value(usageLabel),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      bytes:
          bytes == null && nullToAbsent ? const Value.absent() : Value(bytes),
      archived: Value(archived),
      createdAt: Value(createdAt),
    );
  }

  factory MediaAssetEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaAssetEntity(
      id: serializer.fromJson<String>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileType: serializer.fromJson<String>(json['fileType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      folder: serializer.fromJson<String>(json['folder']),
      usageLabel: serializer.fromJson<String>(json['usageLabel']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      bytes: serializer.fromJson<Uint8List?>(json['bytes']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fileName': serializer.toJson<String>(fileName),
      'fileType': serializer.toJson<String>(fileType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'folder': serializer.toJson<String>(folder),
      'usageLabel': serializer.toJson<String>(usageLabel),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'bytes': serializer.toJson<Uint8List?>(bytes),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MediaAssetEntity copyWith(
          {String? id,
          String? fileName,
          String? fileType,
          int? sizeBytes,
          String? folder,
          String? usageLabel,
          Value<String?> imageUrl = const Value.absent(),
          Value<Uint8List?> bytes = const Value.absent(),
          bool? archived,
          DateTime? createdAt}) =>
      MediaAssetEntity(
        id: id ?? this.id,
        fileName: fileName ?? this.fileName,
        fileType: fileType ?? this.fileType,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        folder: folder ?? this.folder,
        usageLabel: usageLabel ?? this.usageLabel,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        bytes: bytes.present ? bytes.value : this.bytes,
        archived: archived ?? this.archived,
        createdAt: createdAt ?? this.createdAt,
      );
  MediaAssetEntity copyWithCompanion(MediaAssetsTableCompanion data) {
    return MediaAssetEntity(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      folder: data.folder.present ? data.folder.value : this.folder,
      usageLabel:
          data.usageLabel.present ? data.usageLabel.value : this.usageLabel,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaAssetEntity(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('fileType: $fileType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('folder: $folder, ')
          ..write('usageLabel: $usageLabel, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('bytes: $bytes, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      fileName,
      fileType,
      sizeBytes,
      folder,
      usageLabel,
      imageUrl,
      $driftBlobEquality.hash(bytes),
      archived,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaAssetEntity &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.fileType == this.fileType &&
          other.sizeBytes == this.sizeBytes &&
          other.folder == this.folder &&
          other.usageLabel == this.usageLabel &&
          other.imageUrl == this.imageUrl &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt);
}

class MediaAssetsTableCompanion extends UpdateCompanion<MediaAssetEntity> {
  final Value<String> id;
  final Value<String> fileName;
  final Value<String> fileType;
  final Value<int> sizeBytes;
  final Value<String> folder;
  final Value<String> usageLabel;
  final Value<String?> imageUrl;
  final Value<Uint8List?> bytes;
  final Value<bool> archived;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MediaAssetsTableCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.folder = const Value.absent(),
    this.usageLabel = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.bytes = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaAssetsTableCompanion.insert({
    required String id,
    required String fileName,
    required String fileType,
    this.sizeBytes = const Value.absent(),
    required String folder,
    this.usageLabel = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.bytes = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        fileName = Value(fileName),
        fileType = Value(fileType),
        folder = Value(folder);
  static Insertable<MediaAssetEntity> custom({
    Expression<String>? id,
    Expression<String>? fileName,
    Expression<String>? fileType,
    Expression<int>? sizeBytes,
    Expression<String>? folder,
    Expression<String>? usageLabel,
    Expression<String>? imageUrl,
    Expression<Uint8List>? bytes,
    Expression<bool>? archived,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (fileType != null) 'file_type': fileType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (folder != null) 'folder': folder,
      if (usageLabel != null) 'usage_label': usageLabel,
      if (imageUrl != null) 'image_url': imageUrl,
      if (bytes != null) 'bytes': bytes,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaAssetsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? fileName,
      Value<String>? fileType,
      Value<int>? sizeBytes,
      Value<String>? folder,
      Value<String>? usageLabel,
      Value<String?>? imageUrl,
      Value<Uint8List?>? bytes,
      Value<bool>? archived,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MediaAssetsTableCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      folder: folder ?? this.folder,
      usageLabel: usageLabel ?? this.usageLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      bytes: bytes ?? this.bytes,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (usageLabel.present) {
      map['usage_label'] = Variable<String>(usageLabel.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaAssetsTableCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('fileType: $fileType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('folder: $folder, ')
          ..write('usageLabel: $usageLabel, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('bytes: $bytes, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipesTableTable extends RecipesTable
    with TableInfo<$RecipesTableTable, RecipeEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('v1.0'));
  static const VerificationMeta _linkedMenuItemIdMeta =
      const VerificationMeta('linkedMenuItemId');
  @override
  late final GeneratedColumn<String> linkedMenuItemId = GeneratedColumn<String>(
      'linked_menu_item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _linkedMenuItemNameMeta =
      const VerificationMeta('linkedMenuItemName');
  @override
  late final GeneratedColumn<String> linkedMenuItemName =
      GeneratedColumn<String>('linked_menu_item_name', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant(''));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _portionMeta =
      const VerificationMeta('portion');
  @override
  late final GeneratedColumn<String> portion = GeneratedColumn<String>(
      'portion', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _targetPriceMeta =
      const VerificationMeta('targetPrice');
  @override
  late final GeneratedColumn<double> targetPrice = GeneratedColumn<double>(
      'target_price', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _laborCostMeta =
      const VerificationMeta('laborCost');
  @override
  late final GeneratedColumn<double> laborCost = GeneratedColumn<double>(
      'labor_cost', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _packagingCostMeta =
      const VerificationMeta('packagingCost');
  @override
  late final GeneratedColumn<double> packagingCost = GeneratedColumn<double>(
      'packaging_cost', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _trialResultMeta =
      const VerificationMeta('trialResult');
  @override
  late final GeneratedColumn<String> trialResult = GeneratedColumn<String>(
      'trial_result', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Pending'));
  static const VerificationMeta _trainingDoneMeta =
      const VerificationMeta('trainingDone');
  @override
  late final GeneratedColumn<int> trainingDone = GeneratedColumn<int>(
      'training_done', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _trainingTotalMeta =
      const VerificationMeta('trainingTotal');
  @override
  late final GeneratedColumn<int> trainingTotal = GeneratedColumn<int>(
      'training_total', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Draft'));
  static const VerificationMeta _prepMethodMeta =
      const VerificationMeta('prepMethod');
  @override
  late final GeneratedColumn<String> prepMethod = GeneratedColumn<String>(
      'prep_method', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _allergensMeta =
      const VerificationMeta('allergens');
  @override
  late final GeneratedColumn<String> allergens = GeneratedColumn<String>(
      'allergens', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _activeChannelsMeta =
      const VerificationMeta('activeChannels');
  @override
  late final GeneratedColumn<String> activeChannels = GeneratedColumn<String>(
      'active_channels', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        code,
        name,
        version,
        linkedMenuItemId,
        linkedMenuItemName,
        category,
        portion,
        targetPrice,
        laborCost,
        packagingCost,
        trialResult,
        trainingDone,
        trainingTotal,
        status,
        prepMethod,
        allergens,
        activeChannels,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes_table';
  @override
  VerificationContext validateIntegrity(Insertable<RecipeEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('linked_menu_item_id')) {
      context.handle(
          _linkedMenuItemIdMeta,
          linkedMenuItemId.isAcceptableOrUnknown(
              data['linked_menu_item_id']!, _linkedMenuItemIdMeta));
    }
    if (data.containsKey('linked_menu_item_name')) {
      context.handle(
          _linkedMenuItemNameMeta,
          linkedMenuItemName.isAcceptableOrUnknown(
              data['linked_menu_item_name']!, _linkedMenuItemNameMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('portion')) {
      context.handle(_portionMeta,
          portion.isAcceptableOrUnknown(data['portion']!, _portionMeta));
    }
    if (data.containsKey('target_price')) {
      context.handle(
          _targetPriceMeta,
          targetPrice.isAcceptableOrUnknown(
              data['target_price']!, _targetPriceMeta));
    }
    if (data.containsKey('labor_cost')) {
      context.handle(_laborCostMeta,
          laborCost.isAcceptableOrUnknown(data['labor_cost']!, _laborCostMeta));
    }
    if (data.containsKey('packaging_cost')) {
      context.handle(
          _packagingCostMeta,
          packagingCost.isAcceptableOrUnknown(
              data['packaging_cost']!, _packagingCostMeta));
    }
    if (data.containsKey('trial_result')) {
      context.handle(
          _trialResultMeta,
          trialResult.isAcceptableOrUnknown(
              data['trial_result']!, _trialResultMeta));
    }
    if (data.containsKey('training_done')) {
      context.handle(
          _trainingDoneMeta,
          trainingDone.isAcceptableOrUnknown(
              data['training_done']!, _trainingDoneMeta));
    }
    if (data.containsKey('training_total')) {
      context.handle(
          _trainingTotalMeta,
          trainingTotal.isAcceptableOrUnknown(
              data['training_total']!, _trainingTotalMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('prep_method')) {
      context.handle(
          _prepMethodMeta,
          prepMethod.isAcceptableOrUnknown(
              data['prep_method']!, _prepMethodMeta));
    }
    if (data.containsKey('allergens')) {
      context.handle(_allergensMeta,
          allergens.isAcceptableOrUnknown(data['allergens']!, _allergensMeta));
    }
    if (data.containsKey('active_channels')) {
      context.handle(
          _activeChannelsMeta,
          activeChannels.isAcceptableOrUnknown(
              data['active_channels']!, _activeChannelsMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      linkedMenuItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}linked_menu_item_id']),
      linkedMenuItemName: attachedDatabase.typeMapping.read(DriftSqlType.string,
          data['${effectivePrefix}linked_menu_item_name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      portion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}portion'])!,
      targetPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_price'])!,
      laborCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}labor_cost'])!,
      packagingCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}packaging_cost'])!,
      trialResult: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trial_result'])!,
      trainingDone: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}training_done'])!,
      trainingTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}training_total'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      prepMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prep_method'])!,
      allergens: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}allergens'])!,
      activeChannels: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}active_channels'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RecipesTableTable createAlias(String alias) {
    return $RecipesTableTable(attachedDatabase, alias);
  }
}

class RecipeEntity extends DataClass implements Insertable<RecipeEntity> {
  final String id;
  final String code;
  final String name;
  final String version;
  final String? linkedMenuItemId;
  final String linkedMenuItemName;
  final String category;
  final String portion;
  final double targetPrice;
  final double laborCost;
  final double packagingCost;
  final String trialResult;
  final int trainingDone;
  final int trainingTotal;
  final String status;
  final String prepMethod;
  final String allergens;
  final String activeChannels;
  final DateTime updatedAt;
  const RecipeEntity(
      {required this.id,
      required this.code,
      required this.name,
      required this.version,
      this.linkedMenuItemId,
      required this.linkedMenuItemName,
      required this.category,
      required this.portion,
      required this.targetPrice,
      required this.laborCost,
      required this.packagingCost,
      required this.trialResult,
      required this.trainingDone,
      required this.trainingTotal,
      required this.status,
      required this.prepMethod,
      required this.allergens,
      required this.activeChannels,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || linkedMenuItemId != null) {
      map['linked_menu_item_id'] = Variable<String>(linkedMenuItemId);
    }
    map['linked_menu_item_name'] = Variable<String>(linkedMenuItemName);
    map['category'] = Variable<String>(category);
    map['portion'] = Variable<String>(portion);
    map['target_price'] = Variable<double>(targetPrice);
    map['labor_cost'] = Variable<double>(laborCost);
    map['packaging_cost'] = Variable<double>(packagingCost);
    map['trial_result'] = Variable<String>(trialResult);
    map['training_done'] = Variable<int>(trainingDone);
    map['training_total'] = Variable<int>(trainingTotal);
    map['status'] = Variable<String>(status);
    map['prep_method'] = Variable<String>(prepMethod);
    map['allergens'] = Variable<String>(allergens);
    map['active_channels'] = Variable<String>(activeChannels);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecipesTableCompanion toCompanion(bool nullToAbsent) {
    return RecipesTableCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      version: Value(version),
      linkedMenuItemId: linkedMenuItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedMenuItemId),
      linkedMenuItemName: Value(linkedMenuItemName),
      category: Value(category),
      portion: Value(portion),
      targetPrice: Value(targetPrice),
      laborCost: Value(laborCost),
      packagingCost: Value(packagingCost),
      trialResult: Value(trialResult),
      trainingDone: Value(trainingDone),
      trainingTotal: Value(trainingTotal),
      status: Value(status),
      prepMethod: Value(prepMethod),
      allergens: Value(allergens),
      activeChannels: Value(activeChannels),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecipeEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeEntity(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      linkedMenuItemId: serializer.fromJson<String?>(json['linkedMenuItemId']),
      linkedMenuItemName:
          serializer.fromJson<String>(json['linkedMenuItemName']),
      category: serializer.fromJson<String>(json['category']),
      portion: serializer.fromJson<String>(json['portion']),
      targetPrice: serializer.fromJson<double>(json['targetPrice']),
      laborCost: serializer.fromJson<double>(json['laborCost']),
      packagingCost: serializer.fromJson<double>(json['packagingCost']),
      trialResult: serializer.fromJson<String>(json['trialResult']),
      trainingDone: serializer.fromJson<int>(json['trainingDone']),
      trainingTotal: serializer.fromJson<int>(json['trainingTotal']),
      status: serializer.fromJson<String>(json['status']),
      prepMethod: serializer.fromJson<String>(json['prepMethod']),
      allergens: serializer.fromJson<String>(json['allergens']),
      activeChannels: serializer.fromJson<String>(json['activeChannels']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'linkedMenuItemId': serializer.toJson<String?>(linkedMenuItemId),
      'linkedMenuItemName': serializer.toJson<String>(linkedMenuItemName),
      'category': serializer.toJson<String>(category),
      'portion': serializer.toJson<String>(portion),
      'targetPrice': serializer.toJson<double>(targetPrice),
      'laborCost': serializer.toJson<double>(laborCost),
      'packagingCost': serializer.toJson<double>(packagingCost),
      'trialResult': serializer.toJson<String>(trialResult),
      'trainingDone': serializer.toJson<int>(trainingDone),
      'trainingTotal': serializer.toJson<int>(trainingTotal),
      'status': serializer.toJson<String>(status),
      'prepMethod': serializer.toJson<String>(prepMethod),
      'allergens': serializer.toJson<String>(allergens),
      'activeChannels': serializer.toJson<String>(activeChannels),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipeEntity copyWith(
          {String? id,
          String? code,
          String? name,
          String? version,
          Value<String?> linkedMenuItemId = const Value.absent(),
          String? linkedMenuItemName,
          String? category,
          String? portion,
          double? targetPrice,
          double? laborCost,
          double? packagingCost,
          String? trialResult,
          int? trainingDone,
          int? trainingTotal,
          String? status,
          String? prepMethod,
          String? allergens,
          String? activeChannels,
          DateTime? updatedAt}) =>
      RecipeEntity(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        version: version ?? this.version,
        linkedMenuItemId: linkedMenuItemId.present
            ? linkedMenuItemId.value
            : this.linkedMenuItemId,
        linkedMenuItemName: linkedMenuItemName ?? this.linkedMenuItemName,
        category: category ?? this.category,
        portion: portion ?? this.portion,
        targetPrice: targetPrice ?? this.targetPrice,
        laborCost: laborCost ?? this.laborCost,
        packagingCost: packagingCost ?? this.packagingCost,
        trialResult: trialResult ?? this.trialResult,
        trainingDone: trainingDone ?? this.trainingDone,
        trainingTotal: trainingTotal ?? this.trainingTotal,
        status: status ?? this.status,
        prepMethod: prepMethod ?? this.prepMethod,
        allergens: allergens ?? this.allergens,
        activeChannels: activeChannels ?? this.activeChannels,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RecipeEntity copyWithCompanion(RecipesTableCompanion data) {
    return RecipeEntity(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      linkedMenuItemId: data.linkedMenuItemId.present
          ? data.linkedMenuItemId.value
          : this.linkedMenuItemId,
      linkedMenuItemName: data.linkedMenuItemName.present
          ? data.linkedMenuItemName.value
          : this.linkedMenuItemName,
      category: data.category.present ? data.category.value : this.category,
      portion: data.portion.present ? data.portion.value : this.portion,
      targetPrice:
          data.targetPrice.present ? data.targetPrice.value : this.targetPrice,
      laborCost: data.laborCost.present ? data.laborCost.value : this.laborCost,
      packagingCost: data.packagingCost.present
          ? data.packagingCost.value
          : this.packagingCost,
      trialResult:
          data.trialResult.present ? data.trialResult.value : this.trialResult,
      trainingDone: data.trainingDone.present
          ? data.trainingDone.value
          : this.trainingDone,
      trainingTotal: data.trainingTotal.present
          ? data.trainingTotal.value
          : this.trainingTotal,
      status: data.status.present ? data.status.value : this.status,
      prepMethod:
          data.prepMethod.present ? data.prepMethod.value : this.prepMethod,
      allergens: data.allergens.present ? data.allergens.value : this.allergens,
      activeChannels: data.activeChannels.present
          ? data.activeChannels.value
          : this.activeChannels,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeEntity(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('linkedMenuItemId: $linkedMenuItemId, ')
          ..write('linkedMenuItemName: $linkedMenuItemName, ')
          ..write('category: $category, ')
          ..write('portion: $portion, ')
          ..write('targetPrice: $targetPrice, ')
          ..write('laborCost: $laborCost, ')
          ..write('packagingCost: $packagingCost, ')
          ..write('trialResult: $trialResult, ')
          ..write('trainingDone: $trainingDone, ')
          ..write('trainingTotal: $trainingTotal, ')
          ..write('status: $status, ')
          ..write('prepMethod: $prepMethod, ')
          ..write('allergens: $allergens, ')
          ..write('activeChannels: $activeChannels, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      code,
      name,
      version,
      linkedMenuItemId,
      linkedMenuItemName,
      category,
      portion,
      targetPrice,
      laborCost,
      packagingCost,
      trialResult,
      trainingDone,
      trainingTotal,
      status,
      prepMethod,
      allergens,
      activeChannels,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeEntity &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.version == this.version &&
          other.linkedMenuItemId == this.linkedMenuItemId &&
          other.linkedMenuItemName == this.linkedMenuItemName &&
          other.category == this.category &&
          other.portion == this.portion &&
          other.targetPrice == this.targetPrice &&
          other.laborCost == this.laborCost &&
          other.packagingCost == this.packagingCost &&
          other.trialResult == this.trialResult &&
          other.trainingDone == this.trainingDone &&
          other.trainingTotal == this.trainingTotal &&
          other.status == this.status &&
          other.prepMethod == this.prepMethod &&
          other.allergens == this.allergens &&
          other.activeChannels == this.activeChannels &&
          other.updatedAt == this.updatedAt);
}

class RecipesTableCompanion extends UpdateCompanion<RecipeEntity> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> version;
  final Value<String?> linkedMenuItemId;
  final Value<String> linkedMenuItemName;
  final Value<String> category;
  final Value<String> portion;
  final Value<double> targetPrice;
  final Value<double> laborCost;
  final Value<double> packagingCost;
  final Value<String> trialResult;
  final Value<int> trainingDone;
  final Value<int> trainingTotal;
  final Value<String> status;
  final Value<String> prepMethod;
  final Value<String> allergens;
  final Value<String> activeChannels;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecipesTableCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.linkedMenuItemId = const Value.absent(),
    this.linkedMenuItemName = const Value.absent(),
    this.category = const Value.absent(),
    this.portion = const Value.absent(),
    this.targetPrice = const Value.absent(),
    this.laborCost = const Value.absent(),
    this.packagingCost = const Value.absent(),
    this.trialResult = const Value.absent(),
    this.trainingDone = const Value.absent(),
    this.trainingTotal = const Value.absent(),
    this.status = const Value.absent(),
    this.prepMethod = const Value.absent(),
    this.allergens = const Value.absent(),
    this.activeChannels = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesTableCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.version = const Value.absent(),
    this.linkedMenuItemId = const Value.absent(),
    this.linkedMenuItemName = const Value.absent(),
    this.category = const Value.absent(),
    this.portion = const Value.absent(),
    this.targetPrice = const Value.absent(),
    this.laborCost = const Value.absent(),
    this.packagingCost = const Value.absent(),
    this.trialResult = const Value.absent(),
    this.trainingDone = const Value.absent(),
    this.trainingTotal = const Value.absent(),
    this.status = const Value.absent(),
    this.prepMethod = const Value.absent(),
    this.allergens = const Value.absent(),
    this.activeChannels = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        code = Value(code),
        name = Value(name);
  static Insertable<RecipeEntity> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? version,
    Expression<String>? linkedMenuItemId,
    Expression<String>? linkedMenuItemName,
    Expression<String>? category,
    Expression<String>? portion,
    Expression<double>? targetPrice,
    Expression<double>? laborCost,
    Expression<double>? packagingCost,
    Expression<String>? trialResult,
    Expression<int>? trainingDone,
    Expression<int>? trainingTotal,
    Expression<String>? status,
    Expression<String>? prepMethod,
    Expression<String>? allergens,
    Expression<String>? activeChannels,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (linkedMenuItemId != null) 'linked_menu_item_id': linkedMenuItemId,
      if (linkedMenuItemName != null)
        'linked_menu_item_name': linkedMenuItemName,
      if (category != null) 'category': category,
      if (portion != null) 'portion': portion,
      if (targetPrice != null) 'target_price': targetPrice,
      if (laborCost != null) 'labor_cost': laborCost,
      if (packagingCost != null) 'packaging_cost': packagingCost,
      if (trialResult != null) 'trial_result': trialResult,
      if (trainingDone != null) 'training_done': trainingDone,
      if (trainingTotal != null) 'training_total': trainingTotal,
      if (status != null) 'status': status,
      if (prepMethod != null) 'prep_method': prepMethod,
      if (allergens != null) 'allergens': allergens,
      if (activeChannels != null) 'active_channels': activeChannels,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? code,
      Value<String>? name,
      Value<String>? version,
      Value<String?>? linkedMenuItemId,
      Value<String>? linkedMenuItemName,
      Value<String>? category,
      Value<String>? portion,
      Value<double>? targetPrice,
      Value<double>? laborCost,
      Value<double>? packagingCost,
      Value<String>? trialResult,
      Value<int>? trainingDone,
      Value<int>? trainingTotal,
      Value<String>? status,
      Value<String>? prepMethod,
      Value<String>? allergens,
      Value<String>? activeChannels,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return RecipesTableCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      version: version ?? this.version,
      linkedMenuItemId: linkedMenuItemId ?? this.linkedMenuItemId,
      linkedMenuItemName: linkedMenuItemName ?? this.linkedMenuItemName,
      category: category ?? this.category,
      portion: portion ?? this.portion,
      targetPrice: targetPrice ?? this.targetPrice,
      laborCost: laborCost ?? this.laborCost,
      packagingCost: packagingCost ?? this.packagingCost,
      trialResult: trialResult ?? this.trialResult,
      trainingDone: trainingDone ?? this.trainingDone,
      trainingTotal: trainingTotal ?? this.trainingTotal,
      status: status ?? this.status,
      prepMethod: prepMethod ?? this.prepMethod,
      allergens: allergens ?? this.allergens,
      activeChannels: activeChannels ?? this.activeChannels,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (linkedMenuItemId.present) {
      map['linked_menu_item_id'] = Variable<String>(linkedMenuItemId.value);
    }
    if (linkedMenuItemName.present) {
      map['linked_menu_item_name'] = Variable<String>(linkedMenuItemName.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (portion.present) {
      map['portion'] = Variable<String>(portion.value);
    }
    if (targetPrice.present) {
      map['target_price'] = Variable<double>(targetPrice.value);
    }
    if (laborCost.present) {
      map['labor_cost'] = Variable<double>(laborCost.value);
    }
    if (packagingCost.present) {
      map['packaging_cost'] = Variable<double>(packagingCost.value);
    }
    if (trialResult.present) {
      map['trial_result'] = Variable<String>(trialResult.value);
    }
    if (trainingDone.present) {
      map['training_done'] = Variable<int>(trainingDone.value);
    }
    if (trainingTotal.present) {
      map['training_total'] = Variable<int>(trainingTotal.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (prepMethod.present) {
      map['prep_method'] = Variable<String>(prepMethod.value);
    }
    if (allergens.present) {
      map['allergens'] = Variable<String>(allergens.value);
    }
    if (activeChannels.present) {
      map['active_channels'] = Variable<String>(activeChannels.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesTableCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('linkedMenuItemId: $linkedMenuItemId, ')
          ..write('linkedMenuItemName: $linkedMenuItemName, ')
          ..write('category: $category, ')
          ..write('portion: $portion, ')
          ..write('targetPrice: $targetPrice, ')
          ..write('laborCost: $laborCost, ')
          ..write('packagingCost: $packagingCost, ')
          ..write('trialResult: $trialResult, ')
          ..write('trainingDone: $trainingDone, ')
          ..write('trainingTotal: $trainingTotal, ')
          ..write('status: $status, ')
          ..write('prepMethod: $prepMethod, ')
          ..write('allergens: $allergens, ')
          ..write('activeChannels: $activeChannels, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeLinesTableTable extends RecipeLinesTable
    with TableInfo<$RecipeLinesTableTable, RecipeLineEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeLinesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
      'recipe_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _materialIdMeta =
      const VerificationMeta('materialId');
  @override
  late final GeneratedColumn<String> materialId = GeneratedColumn<String>(
      'material_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
      'qty', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _wastagePctMeta =
      const VerificationMeta('wastagePct');
  @override
  late final GeneratedColumn<double> wastagePct = GeneratedColumn<double>(
      'wastage_pct', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _fallbackUnitCostMeta =
      const VerificationMeta('fallbackUnitCost');
  @override
  late final GeneratedColumn<double> fallbackUnitCost = GeneratedColumn<double>(
      'fallback_unit_cost', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isKeyMeta = const VerificationMeta('isKey');
  @override
  late final GeneratedColumn<bool> isKey = GeneratedColumn<bool>(
      'is_key', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_key" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _substituteMeta =
      const VerificationMeta('substitute');
  @override
  late final GeneratedColumn<String> substitute = GeneratedColumn<String>(
      'substitute', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        recipeId,
        materialId,
        name,
        qty,
        unit,
        wastagePct,
        fallbackUnitCost,
        isKey,
        substitute
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_lines_table';
  @override
  VerificationContext validateIntegrity(Insertable<RecipeLineEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('material_id')) {
      context.handle(
          _materialIdMeta,
          materialId.isAcceptableOrUnknown(
              data['material_id']!, _materialIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('wastage_pct')) {
      context.handle(
          _wastagePctMeta,
          wastagePct.isAcceptableOrUnknown(
              data['wastage_pct']!, _wastagePctMeta));
    }
    if (data.containsKey('fallback_unit_cost')) {
      context.handle(
          _fallbackUnitCostMeta,
          fallbackUnitCost.isAcceptableOrUnknown(
              data['fallback_unit_cost']!, _fallbackUnitCostMeta));
    }
    if (data.containsKey('is_key')) {
      context.handle(
          _isKeyMeta, isKey.isAcceptableOrUnknown(data['is_key']!, _isKeyMeta));
    }
    if (data.containsKey('substitute')) {
      context.handle(
          _substituteMeta,
          substitute.isAcceptableOrUnknown(
              data['substitute']!, _substituteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeLineEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeLineEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_id'])!,
      materialId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qty'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      wastagePct: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}wastage_pct'])!,
      fallbackUnitCost: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}fallback_unit_cost'])!,
      isKey: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_key'])!,
      substitute: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}substitute'])!,
    );
  }

  @override
  $RecipeLinesTableTable createAlias(String alias) {
    return $RecipeLinesTableTable(attachedDatabase, alias);
  }
}

class RecipeLineEntity extends DataClass
    implements Insertable<RecipeLineEntity> {
  final int id;
  final String recipeId;
  final String? materialId;
  final String name;

  /// Quantity per portion in the material's own unit (kg / L / pcs).
  final double qty;
  final String unit;
  final double wastagePct;

  /// Price used when the line has no linked raw material.
  final double fallbackUnitCost;
  final bool isKey;
  final String substitute;
  const RecipeLineEntity(
      {required this.id,
      required this.recipeId,
      this.materialId,
      required this.name,
      required this.qty,
      required this.unit,
      required this.wastagePct,
      required this.fallbackUnitCost,
      required this.isKey,
      required this.substitute});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    if (!nullToAbsent || materialId != null) {
      map['material_id'] = Variable<String>(materialId);
    }
    map['name'] = Variable<String>(name);
    map['qty'] = Variable<double>(qty);
    map['unit'] = Variable<String>(unit);
    map['wastage_pct'] = Variable<double>(wastagePct);
    map['fallback_unit_cost'] = Variable<double>(fallbackUnitCost);
    map['is_key'] = Variable<bool>(isKey);
    map['substitute'] = Variable<String>(substitute);
    return map;
  }

  RecipeLinesTableCompanion toCompanion(bool nullToAbsent) {
    return RecipeLinesTableCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      materialId: materialId == null && nullToAbsent
          ? const Value.absent()
          : Value(materialId),
      name: Value(name),
      qty: Value(qty),
      unit: Value(unit),
      wastagePct: Value(wastagePct),
      fallbackUnitCost: Value(fallbackUnitCost),
      isKey: Value(isKey),
      substitute: Value(substitute),
    );
  }

  factory RecipeLineEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeLineEntity(
      id: serializer.fromJson<int>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      materialId: serializer.fromJson<String?>(json['materialId']),
      name: serializer.fromJson<String>(json['name']),
      qty: serializer.fromJson<double>(json['qty']),
      unit: serializer.fromJson<String>(json['unit']),
      wastagePct: serializer.fromJson<double>(json['wastagePct']),
      fallbackUnitCost: serializer.fromJson<double>(json['fallbackUnitCost']),
      isKey: serializer.fromJson<bool>(json['isKey']),
      substitute: serializer.fromJson<String>(json['substitute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'materialId': serializer.toJson<String?>(materialId),
      'name': serializer.toJson<String>(name),
      'qty': serializer.toJson<double>(qty),
      'unit': serializer.toJson<String>(unit),
      'wastagePct': serializer.toJson<double>(wastagePct),
      'fallbackUnitCost': serializer.toJson<double>(fallbackUnitCost),
      'isKey': serializer.toJson<bool>(isKey),
      'substitute': serializer.toJson<String>(substitute),
    };
  }

  RecipeLineEntity copyWith(
          {int? id,
          String? recipeId,
          Value<String?> materialId = const Value.absent(),
          String? name,
          double? qty,
          String? unit,
          double? wastagePct,
          double? fallbackUnitCost,
          bool? isKey,
          String? substitute}) =>
      RecipeLineEntity(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        materialId: materialId.present ? materialId.value : this.materialId,
        name: name ?? this.name,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        wastagePct: wastagePct ?? this.wastagePct,
        fallbackUnitCost: fallbackUnitCost ?? this.fallbackUnitCost,
        isKey: isKey ?? this.isKey,
        substitute: substitute ?? this.substitute,
      );
  RecipeLineEntity copyWithCompanion(RecipeLinesTableCompanion data) {
    return RecipeLineEntity(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      materialId:
          data.materialId.present ? data.materialId.value : this.materialId,
      name: data.name.present ? data.name.value : this.name,
      qty: data.qty.present ? data.qty.value : this.qty,
      unit: data.unit.present ? data.unit.value : this.unit,
      wastagePct:
          data.wastagePct.present ? data.wastagePct.value : this.wastagePct,
      fallbackUnitCost: data.fallbackUnitCost.present
          ? data.fallbackUnitCost.value
          : this.fallbackUnitCost,
      isKey: data.isKey.present ? data.isKey.value : this.isKey,
      substitute:
          data.substitute.present ? data.substitute.value : this.substitute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeLineEntity(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('materialId: $materialId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('unit: $unit, ')
          ..write('wastagePct: $wastagePct, ')
          ..write('fallbackUnitCost: $fallbackUnitCost, ')
          ..write('isKey: $isKey, ')
          ..write('substitute: $substitute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recipeId, materialId, name, qty, unit,
      wastagePct, fallbackUnitCost, isKey, substitute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeLineEntity &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.materialId == this.materialId &&
          other.name == this.name &&
          other.qty == this.qty &&
          other.unit == this.unit &&
          other.wastagePct == this.wastagePct &&
          other.fallbackUnitCost == this.fallbackUnitCost &&
          other.isKey == this.isKey &&
          other.substitute == this.substitute);
}

class RecipeLinesTableCompanion extends UpdateCompanion<RecipeLineEntity> {
  final Value<int> id;
  final Value<String> recipeId;
  final Value<String?> materialId;
  final Value<String> name;
  final Value<double> qty;
  final Value<String> unit;
  final Value<double> wastagePct;
  final Value<double> fallbackUnitCost;
  final Value<bool> isKey;
  final Value<String> substitute;
  const RecipeLinesTableCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.materialId = const Value.absent(),
    this.name = const Value.absent(),
    this.qty = const Value.absent(),
    this.unit = const Value.absent(),
    this.wastagePct = const Value.absent(),
    this.fallbackUnitCost = const Value.absent(),
    this.isKey = const Value.absent(),
    this.substitute = const Value.absent(),
  });
  RecipeLinesTableCompanion.insert({
    this.id = const Value.absent(),
    required String recipeId,
    this.materialId = const Value.absent(),
    required String name,
    required double qty,
    required String unit,
    this.wastagePct = const Value.absent(),
    this.fallbackUnitCost = const Value.absent(),
    this.isKey = const Value.absent(),
    this.substitute = const Value.absent(),
  })  : recipeId = Value(recipeId),
        name = Value(name),
        qty = Value(qty),
        unit = Value(unit);
  static Insertable<RecipeLineEntity> custom({
    Expression<int>? id,
    Expression<String>? recipeId,
    Expression<String>? materialId,
    Expression<String>? name,
    Expression<double>? qty,
    Expression<String>? unit,
    Expression<double>? wastagePct,
    Expression<double>? fallbackUnitCost,
    Expression<bool>? isKey,
    Expression<String>? substitute,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (materialId != null) 'material_id': materialId,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (unit != null) 'unit': unit,
      if (wastagePct != null) 'wastage_pct': wastagePct,
      if (fallbackUnitCost != null) 'fallback_unit_cost': fallbackUnitCost,
      if (isKey != null) 'is_key': isKey,
      if (substitute != null) 'substitute': substitute,
    });
  }

  RecipeLinesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? recipeId,
      Value<String?>? materialId,
      Value<String>? name,
      Value<double>? qty,
      Value<String>? unit,
      Value<double>? wastagePct,
      Value<double>? fallbackUnitCost,
      Value<bool>? isKey,
      Value<String>? substitute}) {
    return RecipeLinesTableCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      materialId: materialId ?? this.materialId,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      wastagePct: wastagePct ?? this.wastagePct,
      fallbackUnitCost: fallbackUnitCost ?? this.fallbackUnitCost,
      isKey: isKey ?? this.isKey,
      substitute: substitute ?? this.substitute,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (materialId.present) {
      map['material_id'] = Variable<String>(materialId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (wastagePct.present) {
      map['wastage_pct'] = Variable<double>(wastagePct.value);
    }
    if (fallbackUnitCost.present) {
      map['fallback_unit_cost'] = Variable<double>(fallbackUnitCost.value);
    }
    if (isKey.present) {
      map['is_key'] = Variable<bool>(isKey.value);
    }
    if (substitute.present) {
      map['substitute'] = Variable<String>(substitute.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeLinesTableCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('materialId: $materialId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('unit: $unit, ')
          ..write('wastagePct: $wastagePct, ')
          ..write('fallbackUnitCost: $fallbackUnitCost, ')
          ..write('isKey: $isKey, ')
          ..write('substitute: $substitute')
          ..write(')'))
        .toString();
  }
}

class $DeliveriesTableTable extends DeliveriesTable
    with TableInfo<$DeliveriesTableTable, DeliveryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _merchantMeta =
      const VerificationMeta('merchant');
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
      'merchant', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _riderNameMeta =
      const VerificationMeta('riderName');
  @override
  late final GeneratedColumn<String> riderName = GeneratedColumn<String>(
      'rider_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _etaMinutesMeta =
      const VerificationMeta('etaMinutes');
  @override
  late final GeneratedColumn<int> etaMinutes = GeneratedColumn<int>(
      'eta_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _distanceKmMeta =
      const VerificationMeta('distanceKm');
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
      'distance_km', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _promisedAtMeta =
      const VerificationMeta('promisedAt');
  @override
  late final GeneratedColumn<DateTime> promisedAt = GeneratedColumn<DateTime>(
      'promised_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        orderId,
        merchant,
        riderName,
        status,
        etaMinutes,
        distanceKm,
        customerName,
        address,
        promisedAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deliveries_table';
  @override
  VerificationContext validateIntegrity(Insertable<DeliveryEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(_merchantMeta,
          merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta));
    } else if (isInserting) {
      context.missing(_merchantMeta);
    }
    if (data.containsKey('rider_name')) {
      context.handle(_riderNameMeta,
          riderName.isAcceptableOrUnknown(data['rider_name']!, _riderNameMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('eta_minutes')) {
      context.handle(
          _etaMinutesMeta,
          etaMinutes.isAcceptableOrUnknown(
              data['eta_minutes']!, _etaMinutesMeta));
    }
    if (data.containsKey('distance_km')) {
      context.handle(
          _distanceKmMeta,
          distanceKm.isAcceptableOrUnknown(
              data['distance_km']!, _distanceKmMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('promised_at')) {
      context.handle(
          _promisedAtMeta,
          promisedAt.isAcceptableOrUnknown(
              data['promised_at']!, _promisedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeliveryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeliveryEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id'])!,
      merchant: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}merchant'])!,
      riderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rider_name']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      etaMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}eta_minutes']),
      distanceKm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_km'])!,
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address'])!,
      promisedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}promised_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DeliveriesTableTable createAlias(String alias) {
    return $DeliveriesTableTable(attachedDatabase, alias);
  }
}

class DeliveryEntity extends DataClass implements Insertable<DeliveryEntity> {
  final String id;
  final String orderId;
  final String merchant;
  final String? riderName;
  final String status;
  final int? etaMinutes;
  final double distanceKm;
  final String customerName;
  final String address;
  final DateTime? promisedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DeliveryEntity(
      {required this.id,
      required this.orderId,
      required this.merchant,
      this.riderName,
      required this.status,
      this.etaMinutes,
      required this.distanceKm,
      required this.customerName,
      required this.address,
      this.promisedAt,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['merchant'] = Variable<String>(merchant);
    if (!nullToAbsent || riderName != null) {
      map['rider_name'] = Variable<String>(riderName);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || etaMinutes != null) {
      map['eta_minutes'] = Variable<int>(etaMinutes);
    }
    map['distance_km'] = Variable<double>(distanceKm);
    map['customer_name'] = Variable<String>(customerName);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || promisedAt != null) {
      map['promised_at'] = Variable<DateTime>(promisedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DeliveriesTableCompanion toCompanion(bool nullToAbsent) {
    return DeliveriesTableCompanion(
      id: Value(id),
      orderId: Value(orderId),
      merchant: Value(merchant),
      riderName: riderName == null && nullToAbsent
          ? const Value.absent()
          : Value(riderName),
      status: Value(status),
      etaMinutes: etaMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(etaMinutes),
      distanceKm: Value(distanceKm),
      customerName: Value(customerName),
      address: Value(address),
      promisedAt: promisedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(promisedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DeliveryEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeliveryEntity(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      merchant: serializer.fromJson<String>(json['merchant']),
      riderName: serializer.fromJson<String?>(json['riderName']),
      status: serializer.fromJson<String>(json['status']),
      etaMinutes: serializer.fromJson<int?>(json['etaMinutes']),
      distanceKm: serializer.fromJson<double>(json['distanceKm']),
      customerName: serializer.fromJson<String>(json['customerName']),
      address: serializer.fromJson<String>(json['address']),
      promisedAt: serializer.fromJson<DateTime?>(json['promisedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'merchant': serializer.toJson<String>(merchant),
      'riderName': serializer.toJson<String?>(riderName),
      'status': serializer.toJson<String>(status),
      'etaMinutes': serializer.toJson<int?>(etaMinutes),
      'distanceKm': serializer.toJson<double>(distanceKm),
      'customerName': serializer.toJson<String>(customerName),
      'address': serializer.toJson<String>(address),
      'promisedAt': serializer.toJson<DateTime?>(promisedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DeliveryEntity copyWith(
          {String? id,
          String? orderId,
          String? merchant,
          Value<String?> riderName = const Value.absent(),
          String? status,
          Value<int?> etaMinutes = const Value.absent(),
          double? distanceKm,
          String? customerName,
          String? address,
          Value<DateTime?> promisedAt = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      DeliveryEntity(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        merchant: merchant ?? this.merchant,
        riderName: riderName.present ? riderName.value : this.riderName,
        status: status ?? this.status,
        etaMinutes: etaMinutes.present ? etaMinutes.value : this.etaMinutes,
        distanceKm: distanceKm ?? this.distanceKm,
        customerName: customerName ?? this.customerName,
        address: address ?? this.address,
        promisedAt: promisedAt.present ? promisedAt.value : this.promisedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DeliveryEntity copyWithCompanion(DeliveriesTableCompanion data) {
    return DeliveryEntity(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      riderName: data.riderName.present ? data.riderName.value : this.riderName,
      status: data.status.present ? data.status.value : this.status,
      etaMinutes:
          data.etaMinutes.present ? data.etaMinutes.value : this.etaMinutes,
      distanceKm:
          data.distanceKm.present ? data.distanceKm.value : this.distanceKm,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      address: data.address.present ? data.address.value : this.address,
      promisedAt:
          data.promisedAt.present ? data.promisedAt.value : this.promisedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryEntity(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('merchant: $merchant, ')
          ..write('riderName: $riderName, ')
          ..write('status: $status, ')
          ..write('etaMinutes: $etaMinutes, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('customerName: $customerName, ')
          ..write('address: $address, ')
          ..write('promisedAt: $promisedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      orderId,
      merchant,
      riderName,
      status,
      etaMinutes,
      distanceKm,
      customerName,
      address,
      promisedAt,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeliveryEntity &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.merchant == this.merchant &&
          other.riderName == this.riderName &&
          other.status == this.status &&
          other.etaMinutes == this.etaMinutes &&
          other.distanceKm == this.distanceKm &&
          other.customerName == this.customerName &&
          other.address == this.address &&
          other.promisedAt == this.promisedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DeliveriesTableCompanion extends UpdateCompanion<DeliveryEntity> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> merchant;
  final Value<String?> riderName;
  final Value<String> status;
  final Value<int?> etaMinutes;
  final Value<double> distanceKm;
  final Value<String> customerName;
  final Value<String> address;
  final Value<DateTime?> promisedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DeliveriesTableCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.riderName = const Value.absent(),
    this.status = const Value.absent(),
    this.etaMinutes = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.customerName = const Value.absent(),
    this.address = const Value.absent(),
    this.promisedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeliveriesTableCompanion.insert({
    required String id,
    required String orderId,
    required String merchant,
    this.riderName = const Value.absent(),
    required String status,
    this.etaMinutes = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.customerName = const Value.absent(),
    this.address = const Value.absent(),
    this.promisedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        orderId = Value(orderId),
        merchant = Value(merchant),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<DeliveryEntity> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? merchant,
    Expression<String>? riderName,
    Expression<String>? status,
    Expression<int>? etaMinutes,
    Expression<double>? distanceKm,
    Expression<String>? customerName,
    Expression<String>? address,
    Expression<DateTime>? promisedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (merchant != null) 'merchant': merchant,
      if (riderName != null) 'rider_name': riderName,
      if (status != null) 'status': status,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (customerName != null) 'customer_name': customerName,
      if (address != null) 'address': address,
      if (promisedAt != null) 'promised_at': promisedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeliveriesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? orderId,
      Value<String>? merchant,
      Value<String?>? riderName,
      Value<String>? status,
      Value<int?>? etaMinutes,
      Value<double>? distanceKm,
      Value<String>? customerName,
      Value<String>? address,
      Value<DateTime?>? promisedAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DeliveriesTableCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      merchant: merchant ?? this.merchant,
      riderName: riderName ?? this.riderName,
      status: status ?? this.status,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      promisedAt: promisedAt ?? this.promisedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (riderName.present) {
      map['rider_name'] = Variable<String>(riderName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (etaMinutes.present) {
      map['eta_minutes'] = Variable<int>(etaMinutes.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (promisedAt.present) {
      map['promised_at'] = Variable<DateTime>(promisedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveriesTableCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('merchant: $merchant, ')
          ..write('riderName: $riderName, ')
          ..write('status: $status, ')
          ..write('etaMinutes: $etaMinutes, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('customerName: $customerName, ')
          ..write('address: $address, ')
          ..write('promisedAt: $promisedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReservationsTableTable extends ReservationsTable
    with TableInfo<$ReservationsTableTable, ReservationEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReservationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _guestNameMeta =
      const VerificationMeta('guestName');
  @override
  late final GeneratedColumn<String> guestName = GeneratedColumn<String>(
      'guest_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _guestsMeta = const VerificationMeta('guests');
  @override
  late final GeneratedColumn<int> guests = GeneratedColumn<int>(
      'guests', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _scheduledAtMeta =
      const VerificationMeta('scheduledAt');
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
      'scheduled_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tableIdMeta =
      const VerificationMeta('tableId');
  @override
  late final GeneratedColumn<String> tableId = GeneratedColumn<String>(
      'table_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        guestName,
        phone,
        email,
        guests,
        scheduledAt,
        status,
        tableId,
        notes,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reservations_table';
  @override
  VerificationContext validateIntegrity(Insertable<ReservationEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('guest_name')) {
      context.handle(_guestNameMeta,
          guestName.isAcceptableOrUnknown(data['guest_name']!, _guestNameMeta));
    } else if (isInserting) {
      context.missing(_guestNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('guests')) {
      context.handle(_guestsMeta,
          guests.isAcceptableOrUnknown(data['guests']!, _guestsMeta));
    } else if (isInserting) {
      context.missing(_guestsMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
          _scheduledAtMeta,
          scheduledAt.isAcceptableOrUnknown(
              data['scheduled_at']!, _scheduledAtMeta));
    } else if (isInserting) {
      context.missing(_scheduledAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('table_id')) {
      context.handle(_tableIdMeta,
          tableId.isAcceptableOrUnknown(data['table_id']!, _tableIdMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReservationEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReservationEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      guestName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}guest_name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      guests: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}guests'])!,
      scheduledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scheduled_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      tableId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_id']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ReservationsTableTable createAlias(String alias) {
    return $ReservationsTableTable(attachedDatabase, alias);
  }
}

class ReservationEntity extends DataClass
    implements Insertable<ReservationEntity> {
  final String id;
  final String guestName;
  final String phone;
  final String email;
  final int guests;
  final DateTime scheduledAt;
  final String status;
  final String? tableId;
  final String notes;
  final DateTime createdAt;
  const ReservationEntity(
      {required this.id,
      required this.guestName,
      required this.phone,
      required this.email,
      required this.guests,
      required this.scheduledAt,
      required this.status,
      this.tableId,
      required this.notes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['guest_name'] = Variable<String>(guestName);
    map['phone'] = Variable<String>(phone);
    map['email'] = Variable<String>(email);
    map['guests'] = Variable<int>(guests);
    map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || tableId != null) {
      map['table_id'] = Variable<String>(tableId);
    }
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReservationsTableCompanion toCompanion(bool nullToAbsent) {
    return ReservationsTableCompanion(
      id: Value(id),
      guestName: Value(guestName),
      phone: Value(phone),
      email: Value(email),
      guests: Value(guests),
      scheduledAt: Value(scheduledAt),
      status: Value(status),
      tableId: tableId == null && nullToAbsent
          ? const Value.absent()
          : Value(tableId),
      notes: Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory ReservationEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReservationEntity(
      id: serializer.fromJson<String>(json['id']),
      guestName: serializer.fromJson<String>(json['guestName']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String>(json['email']),
      guests: serializer.fromJson<int>(json['guests']),
      scheduledAt: serializer.fromJson<DateTime>(json['scheduledAt']),
      status: serializer.fromJson<String>(json['status']),
      tableId: serializer.fromJson<String?>(json['tableId']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'guestName': serializer.toJson<String>(guestName),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String>(email),
      'guests': serializer.toJson<int>(guests),
      'scheduledAt': serializer.toJson<DateTime>(scheduledAt),
      'status': serializer.toJson<String>(status),
      'tableId': serializer.toJson<String?>(tableId),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReservationEntity copyWith(
          {String? id,
          String? guestName,
          String? phone,
          String? email,
          int? guests,
          DateTime? scheduledAt,
          String? status,
          Value<String?> tableId = const Value.absent(),
          String? notes,
          DateTime? createdAt}) =>
      ReservationEntity(
        id: id ?? this.id,
        guestName: guestName ?? this.guestName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        guests: guests ?? this.guests,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        status: status ?? this.status,
        tableId: tableId.present ? tableId.value : this.tableId,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
  ReservationEntity copyWithCompanion(ReservationsTableCompanion data) {
    return ReservationEntity(
      id: data.id.present ? data.id.value : this.id,
      guestName: data.guestName.present ? data.guestName.value : this.guestName,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      guests: data.guests.present ? data.guests.value : this.guests,
      scheduledAt:
          data.scheduledAt.present ? data.scheduledAt.value : this.scheduledAt,
      status: data.status.present ? data.status.value : this.status,
      tableId: data.tableId.present ? data.tableId.value : this.tableId,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReservationEntity(')
          ..write('id: $id, ')
          ..write('guestName: $guestName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('guests: $guests, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('status: $status, ')
          ..write('tableId: $tableId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, guestName, phone, email, guests,
      scheduledAt, status, tableId, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReservationEntity &&
          other.id == this.id &&
          other.guestName == this.guestName &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.guests == this.guests &&
          other.scheduledAt == this.scheduledAt &&
          other.status == this.status &&
          other.tableId == this.tableId &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class ReservationsTableCompanion extends UpdateCompanion<ReservationEntity> {
  final Value<String> id;
  final Value<String> guestName;
  final Value<String> phone;
  final Value<String> email;
  final Value<int> guests;
  final Value<DateTime> scheduledAt;
  final Value<String> status;
  final Value<String?> tableId;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ReservationsTableCompanion({
    this.id = const Value.absent(),
    this.guestName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.guests = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.status = const Value.absent(),
    this.tableId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReservationsTableCompanion.insert({
    required String id,
    required String guestName,
    required String phone,
    this.email = const Value.absent(),
    required int guests,
    required DateTime scheduledAt,
    required String status,
    this.tableId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        guestName = Value(guestName),
        phone = Value(phone),
        guests = Value(guests),
        scheduledAt = Value(scheduledAt),
        status = Value(status);
  static Insertable<ReservationEntity> custom({
    Expression<String>? id,
    Expression<String>? guestName,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<int>? guests,
    Expression<DateTime>? scheduledAt,
    Expression<String>? status,
    Expression<String>? tableId,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (guestName != null) 'guest_name': guestName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (guests != null) 'guests': guests,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (status != null) 'status': status,
      if (tableId != null) 'table_id': tableId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReservationsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? guestName,
      Value<String>? phone,
      Value<String>? email,
      Value<int>? guests,
      Value<DateTime>? scheduledAt,
      Value<String>? status,
      Value<String?>? tableId,
      Value<String>? notes,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ReservationsTableCompanion(
      id: id ?? this.id,
      guestName: guestName ?? this.guestName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      guests: guests ?? this.guests,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      tableId: tableId ?? this.tableId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (guestName.present) {
      map['guest_name'] = Variable<String>(guestName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (guests.present) {
      map['guests'] = Variable<int>(guests.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (tableId.present) {
      map['table_id'] = Variable<String>(tableId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReservationsTableCompanion(')
          ..write('id: $id, ')
          ..write('guestName: $guestName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('guests: $guests, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('status: $status, ')
          ..write('tableId: $tableId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QrCodesTableTable extends QrCodesTable
    with TableInfo<$QrCodesTableTable, QrCodeEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QrCodesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tableIdMeta =
      const VerificationMeta('tableId');
  @override
  late final GeneratedColumn<String> tableId = GeneratedColumn<String>(
      'table_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastScannedAtMeta =
      const VerificationMeta('lastScannedAt');
  @override
  late final GeneratedColumn<DateTime> lastScannedAt =
      GeneratedColumn<DateTime>('last_scanned_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [tableId, enabled, token, lastScannedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qr_codes_table';
  @override
  VerificationContext validateIntegrity(Insertable<QrCodeEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('table_id')) {
      context.handle(_tableIdMeta,
          tableId.isAcceptableOrUnknown(data['table_id']!, _tableIdMeta));
    } else if (isInserting) {
      context.missing(_tableIdMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token']!, _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('last_scanned_at')) {
      context.handle(
          _lastScannedAtMeta,
          lastScannedAt.isAcceptableOrUnknown(
              data['last_scanned_at']!, _lastScannedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tableId};
  @override
  QrCodeEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QrCodeEntity(
      tableId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_id'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      token: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token'])!,
      lastScannedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_scanned_at']),
    );
  }

  @override
  $QrCodesTableTable createAlias(String alias) {
    return $QrCodesTableTable(attachedDatabase, alias);
  }
}

class QrCodeEntity extends DataClass implements Insertable<QrCodeEntity> {
  final String tableId;
  final bool enabled;
  final String token;
  final DateTime? lastScannedAt;
  const QrCodeEntity(
      {required this.tableId,
      required this.enabled,
      required this.token,
      this.lastScannedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['table_id'] = Variable<String>(tableId);
    map['enabled'] = Variable<bool>(enabled);
    map['token'] = Variable<String>(token);
    if (!nullToAbsent || lastScannedAt != null) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt);
    }
    return map;
  }

  QrCodesTableCompanion toCompanion(bool nullToAbsent) {
    return QrCodesTableCompanion(
      tableId: Value(tableId),
      enabled: Value(enabled),
      token: Value(token),
      lastScannedAt: lastScannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScannedAt),
    );
  }

  factory QrCodeEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QrCodeEntity(
      tableId: serializer.fromJson<String>(json['tableId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      token: serializer.fromJson<String>(json['token']),
      lastScannedAt: serializer.fromJson<DateTime?>(json['lastScannedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tableId': serializer.toJson<String>(tableId),
      'enabled': serializer.toJson<bool>(enabled),
      'token': serializer.toJson<String>(token),
      'lastScannedAt': serializer.toJson<DateTime?>(lastScannedAt),
    };
  }

  QrCodeEntity copyWith(
          {String? tableId,
          bool? enabled,
          String? token,
          Value<DateTime?> lastScannedAt = const Value.absent()}) =>
      QrCodeEntity(
        tableId: tableId ?? this.tableId,
        enabled: enabled ?? this.enabled,
        token: token ?? this.token,
        lastScannedAt:
            lastScannedAt.present ? lastScannedAt.value : this.lastScannedAt,
      );
  QrCodeEntity copyWithCompanion(QrCodesTableCompanion data) {
    return QrCodeEntity(
      tableId: data.tableId.present ? data.tableId.value : this.tableId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      token: data.token.present ? data.token.value : this.token,
      lastScannedAt: data.lastScannedAt.present
          ? data.lastScannedAt.value
          : this.lastScannedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QrCodeEntity(')
          ..write('tableId: $tableId, ')
          ..write('enabled: $enabled, ')
          ..write('token: $token, ')
          ..write('lastScannedAt: $lastScannedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tableId, enabled, token, lastScannedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QrCodeEntity &&
          other.tableId == this.tableId &&
          other.enabled == this.enabled &&
          other.token == this.token &&
          other.lastScannedAt == this.lastScannedAt);
}

class QrCodesTableCompanion extends UpdateCompanion<QrCodeEntity> {
  final Value<String> tableId;
  final Value<bool> enabled;
  final Value<String> token;
  final Value<DateTime?> lastScannedAt;
  final Value<int> rowid;
  const QrCodesTableCompanion({
    this.tableId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.token = const Value.absent(),
    this.lastScannedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QrCodesTableCompanion.insert({
    required String tableId,
    this.enabled = const Value.absent(),
    required String token,
    this.lastScannedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : tableId = Value(tableId),
        token = Value(token);
  static Insertable<QrCodeEntity> custom({
    Expression<String>? tableId,
    Expression<bool>? enabled,
    Expression<String>? token,
    Expression<DateTime>? lastScannedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tableId != null) 'table_id': tableId,
      if (enabled != null) 'enabled': enabled,
      if (token != null) 'token': token,
      if (lastScannedAt != null) 'last_scanned_at': lastScannedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QrCodesTableCompanion copyWith(
      {Value<String>? tableId,
      Value<bool>? enabled,
      Value<String>? token,
      Value<DateTime?>? lastScannedAt,
      Value<int>? rowid}) {
    return QrCodesTableCompanion(
      tableId: tableId ?? this.tableId,
      enabled: enabled ?? this.enabled,
      token: token ?? this.token,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tableId.present) {
      map['table_id'] = Variable<String>(tableId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (lastScannedAt.present) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QrCodesTableCompanion(')
          ..write('tableId: $tableId, ')
          ..write('enabled: $enabled, ')
          ..write('token: $token, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QrSessionsTableTable extends QrSessionsTable
    with TableInfo<$QrSessionsTableTable, QrSessionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QrSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tableLabelMeta =
      const VerificationMeta('tableLabel');
  @override
  late final GeneratedColumn<String> tableLabel = GeneratedColumn<String>(
      'table_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _guestsMeta = const VerificationMeta('guests');
  @override
  late final GeneratedColumn<int> guests = GeneratedColumn<int>(
      'guests', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _itemCountMeta =
      const VerificationMeta('itemCount');
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
      'item_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalMinorMeta =
      const VerificationMeta('totalMinor');
  @override
  late final GeneratedColumn<int> totalMinor = GeneratedColumn<int>(
      'total_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _closedAtMeta =
      const VerificationMeta('closedAt');
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
      'closed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tableLabel,
        guests,
        startedAt,
        status,
        orderId,
        itemCount,
        totalMinor,
        closedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qr_sessions_table';
  @override
  VerificationContext validateIntegrity(Insertable<QrSessionEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('table_label')) {
      context.handle(
          _tableLabelMeta,
          tableLabel.isAcceptableOrUnknown(
              data['table_label']!, _tableLabelMeta));
    } else if (isInserting) {
      context.missing(_tableLabelMeta);
    }
    if (data.containsKey('guests')) {
      context.handle(_guestsMeta,
          guests.isAcceptableOrUnknown(data['guests']!, _guestsMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    }
    if (data.containsKey('item_count')) {
      context.handle(_itemCountMeta,
          itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta));
    }
    if (data.containsKey('total_minor')) {
      context.handle(
          _totalMinorMeta,
          totalMinor.isAcceptableOrUnknown(
              data['total_minor']!, _totalMinorMeta));
    }
    if (data.containsKey('closed_at')) {
      context.handle(_closedAtMeta,
          closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QrSessionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QrSessionEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tableLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_label'])!,
      guests: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}guests'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id']),
      itemCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_count'])!,
      totalMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_minor'])!,
      closedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}closed_at']),
    );
  }

  @override
  $QrSessionsTableTable createAlias(String alias) {
    return $QrSessionsTableTable(attachedDatabase, alias);
  }
}

class QrSessionEntity extends DataClass implements Insertable<QrSessionEntity> {
  final String id;
  final String tableLabel;
  final int guests;
  final DateTime startedAt;
  final String status;
  final String? orderId;
  final int itemCount;
  final int totalMinor;
  final DateTime? closedAt;
  const QrSessionEntity(
      {required this.id,
      required this.tableLabel,
      required this.guests,
      required this.startedAt,
      required this.status,
      this.orderId,
      required this.itemCount,
      required this.totalMinor,
      this.closedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['table_label'] = Variable<String>(tableLabel);
    map['guests'] = Variable<int>(guests);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    map['item_count'] = Variable<int>(itemCount);
    map['total_minor'] = Variable<int>(totalMinor);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    return map;
  }

  QrSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return QrSessionsTableCompanion(
      id: Value(id),
      tableLabel: Value(tableLabel),
      guests: Value(guests),
      startedAt: Value(startedAt),
      status: Value(status),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      itemCount: Value(itemCount),
      totalMinor: Value(totalMinor),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
    );
  }

  factory QrSessionEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QrSessionEntity(
      id: serializer.fromJson<String>(json['id']),
      tableLabel: serializer.fromJson<String>(json['tableLabel']),
      guests: serializer.fromJson<int>(json['guests']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      status: serializer.fromJson<String>(json['status']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      totalMinor: serializer.fromJson<int>(json['totalMinor']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tableLabel': serializer.toJson<String>(tableLabel),
      'guests': serializer.toJson<int>(guests),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'status': serializer.toJson<String>(status),
      'orderId': serializer.toJson<String?>(orderId),
      'itemCount': serializer.toJson<int>(itemCount),
      'totalMinor': serializer.toJson<int>(totalMinor),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
    };
  }

  QrSessionEntity copyWith(
          {String? id,
          String? tableLabel,
          int? guests,
          DateTime? startedAt,
          String? status,
          Value<String?> orderId = const Value.absent(),
          int? itemCount,
          int? totalMinor,
          Value<DateTime?> closedAt = const Value.absent()}) =>
      QrSessionEntity(
        id: id ?? this.id,
        tableLabel: tableLabel ?? this.tableLabel,
        guests: guests ?? this.guests,
        startedAt: startedAt ?? this.startedAt,
        status: status ?? this.status,
        orderId: orderId.present ? orderId.value : this.orderId,
        itemCount: itemCount ?? this.itemCount,
        totalMinor: totalMinor ?? this.totalMinor,
        closedAt: closedAt.present ? closedAt.value : this.closedAt,
      );
  QrSessionEntity copyWithCompanion(QrSessionsTableCompanion data) {
    return QrSessionEntity(
      id: data.id.present ? data.id.value : this.id,
      tableLabel:
          data.tableLabel.present ? data.tableLabel.value : this.tableLabel,
      guests: data.guests.present ? data.guests.value : this.guests,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      status: data.status.present ? data.status.value : this.status,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      totalMinor:
          data.totalMinor.present ? data.totalMinor.value : this.totalMinor,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QrSessionEntity(')
          ..write('id: $id, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('guests: $guests, ')
          ..write('startedAt: $startedAt, ')
          ..write('status: $status, ')
          ..write('orderId: $orderId, ')
          ..write('itemCount: $itemCount, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('closedAt: $closedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tableLabel, guests, startedAt, status,
      orderId, itemCount, totalMinor, closedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QrSessionEntity &&
          other.id == this.id &&
          other.tableLabel == this.tableLabel &&
          other.guests == this.guests &&
          other.startedAt == this.startedAt &&
          other.status == this.status &&
          other.orderId == this.orderId &&
          other.itemCount == this.itemCount &&
          other.totalMinor == this.totalMinor &&
          other.closedAt == this.closedAt);
}

class QrSessionsTableCompanion extends UpdateCompanion<QrSessionEntity> {
  final Value<String> id;
  final Value<String> tableLabel;
  final Value<int> guests;
  final Value<DateTime> startedAt;
  final Value<String> status;
  final Value<String?> orderId;
  final Value<int> itemCount;
  final Value<int> totalMinor;
  final Value<DateTime?> closedAt;
  final Value<int> rowid;
  const QrSessionsTableCompanion({
    this.id = const Value.absent(),
    this.tableLabel = const Value.absent(),
    this.guests = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.orderId = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QrSessionsTableCompanion.insert({
    required String id,
    required String tableLabel,
    this.guests = const Value.absent(),
    required DateTime startedAt,
    required String status,
    this.orderId = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tableLabel = Value(tableLabel),
        startedAt = Value(startedAt),
        status = Value(status);
  static Insertable<QrSessionEntity> custom({
    Expression<String>? id,
    Expression<String>? tableLabel,
    Expression<int>? guests,
    Expression<DateTime>? startedAt,
    Expression<String>? status,
    Expression<String>? orderId,
    Expression<int>? itemCount,
    Expression<int>? totalMinor,
    Expression<DateTime>? closedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableLabel != null) 'table_label': tableLabel,
      if (guests != null) 'guests': guests,
      if (startedAt != null) 'started_at': startedAt,
      if (status != null) 'status': status,
      if (orderId != null) 'order_id': orderId,
      if (itemCount != null) 'item_count': itemCount,
      if (totalMinor != null) 'total_minor': totalMinor,
      if (closedAt != null) 'closed_at': closedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QrSessionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? tableLabel,
      Value<int>? guests,
      Value<DateTime>? startedAt,
      Value<String>? status,
      Value<String?>? orderId,
      Value<int>? itemCount,
      Value<int>? totalMinor,
      Value<DateTime?>? closedAt,
      Value<int>? rowid}) {
    return QrSessionsTableCompanion(
      id: id ?? this.id,
      tableLabel: tableLabel ?? this.tableLabel,
      guests: guests ?? this.guests,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      itemCount: itemCount ?? this.itemCount,
      totalMinor: totalMinor ?? this.totalMinor,
      closedAt: closedAt ?? this.closedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tableLabel.present) {
      map['table_label'] = Variable<String>(tableLabel.value);
    }
    if (guests.present) {
      map['guests'] = Variable<int>(guests.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (totalMinor.present) {
      map['total_minor'] = Variable<int>(totalMinor.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QrSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('guests: $guests, ')
          ..write('startedAt: $startedAt, ')
          ..write('status: $status, ')
          ..write('orderId: $orderId, ')
          ..write('itemCount: $itemCount, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('closedAt: $closedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRowStatesTable extends SyncRowStates
    with TableInfo<$SyncRowStatesTable, SyncRowStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRowStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localTableMeta =
      const VerificationMeta('localTable');
  @override
  late final GeneratedColumn<String> localTable = GeneratedColumn<String>(
      'local_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
      'row_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keyJsonMeta =
      const VerificationMeta('keyJson');
  @override
  late final GeneratedColumn<String> keyJson = GeneratedColumn<String>(
      'key_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rowHashMeta =
      const VerificationMeta('rowHash');
  @override
  late final GeneratedColumn<String> rowHash = GeneratedColumn<String>(
      'row_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverVersionMeta =
      const VerificationMeta('serverVersion');
  @override
  late final GeneratedColumn<String> serverVersion = GeneratedColumn<String>(
      'server_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _rejectedHashMeta =
      const VerificationMeta('rejectedHash');
  @override
  late final GeneratedColumn<String> rejectedHash = GeneratedColumn<String>(
      'rejected_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        localTable,
        rowKey,
        keyJson,
        rowHash,
        serverVersion,
        status,
        rejectedHash,
        lastError,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_row_states';
  @override
  VerificationContext validateIntegrity(Insertable<SyncRowStateRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_table')) {
      context.handle(
          _localTableMeta,
          localTable.isAcceptableOrUnknown(
              data['local_table']!, _localTableMeta));
    } else if (isInserting) {
      context.missing(_localTableMeta);
    }
    if (data.containsKey('row_key')) {
      context.handle(_rowKeyMeta,
          rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta));
    } else if (isInserting) {
      context.missing(_rowKeyMeta);
    }
    if (data.containsKey('key_json')) {
      context.handle(_keyJsonMeta,
          keyJson.isAcceptableOrUnknown(data['key_json']!, _keyJsonMeta));
    } else if (isInserting) {
      context.missing(_keyJsonMeta);
    }
    if (data.containsKey('row_hash')) {
      context.handle(_rowHashMeta,
          rowHash.isAcceptableOrUnknown(data['row_hash']!, _rowHashMeta));
    } else if (isInserting) {
      context.missing(_rowHashMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
          _serverVersionMeta,
          serverVersion.isAcceptableOrUnknown(
              data['server_version']!, _serverVersionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('rejected_hash')) {
      context.handle(
          _rejectedHashMeta,
          rejectedHash.isAcceptableOrUnknown(
              data['rejected_hash']!, _rejectedHashMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localTable, rowKey};
  @override
  SyncRowStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRowStateRow(
      localTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_table'])!,
      rowKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}row_key'])!,
      keyJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key_json'])!,
      rowHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}row_hash'])!,
      serverVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_version']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      rejectedHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rejected_hash']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $SyncRowStatesTable createAlias(String alias) {
    return $SyncRowStatesTable(attachedDatabase, alias);
  }
}

class SyncRowStateRow extends DataClass implements Insertable<SyncRowStateRow> {
  /// Drift table name of the synced row.
  final String localTable;

  /// Primary-key values joined with "|".
  final String rowKey;

  /// The primary-key columns as JSON (for building delete changes).
  final String keyJson;

  /// Content hash when last in sync with the server.
  final String rowHash;

  /// Server version (update timestamp) last seen, for conflict checks.
  final String? serverVersion;

  /// synced | conflict | rejected
  final String status;

  /// Content hash the server refused (conflict / permanent rejection);
  /// that exact content isn't re-sent until it changes.
  final String? rejectedHash;
  final String? lastError;
  final DateTime syncedAt;
  const SyncRowStateRow(
      {required this.localTable,
      required this.rowKey,
      required this.keyJson,
      required this.rowHash,
      this.serverVersion,
      required this.status,
      this.rejectedHash,
      this.lastError,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_table'] = Variable<String>(localTable);
    map['row_key'] = Variable<String>(rowKey);
    map['key_json'] = Variable<String>(keyJson);
    map['row_hash'] = Variable<String>(rowHash);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<String>(serverVersion);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || rejectedHash != null) {
      map['rejected_hash'] = Variable<String>(rejectedHash);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  SyncRowStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncRowStatesCompanion(
      localTable: Value(localTable),
      rowKey: Value(rowKey),
      keyJson: Value(keyJson),
      rowHash: Value(rowHash),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      status: Value(status),
      rejectedHash: rejectedHash == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectedHash),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      syncedAt: Value(syncedAt),
    );
  }

  factory SyncRowStateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRowStateRow(
      localTable: serializer.fromJson<String>(json['localTable']),
      rowKey: serializer.fromJson<String>(json['rowKey']),
      keyJson: serializer.fromJson<String>(json['keyJson']),
      rowHash: serializer.fromJson<String>(json['rowHash']),
      serverVersion: serializer.fromJson<String?>(json['serverVersion']),
      status: serializer.fromJson<String>(json['status']),
      rejectedHash: serializer.fromJson<String?>(json['rejectedHash']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localTable': serializer.toJson<String>(localTable),
      'rowKey': serializer.toJson<String>(rowKey),
      'keyJson': serializer.toJson<String>(keyJson),
      'rowHash': serializer.toJson<String>(rowHash),
      'serverVersion': serializer.toJson<String?>(serverVersion),
      'status': serializer.toJson<String>(status),
      'rejectedHash': serializer.toJson<String?>(rejectedHash),
      'lastError': serializer.toJson<String?>(lastError),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  SyncRowStateRow copyWith(
          {String? localTable,
          String? rowKey,
          String? keyJson,
          String? rowHash,
          Value<String?> serverVersion = const Value.absent(),
          String? status,
          Value<String?> rejectedHash = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          DateTime? syncedAt}) =>
      SyncRowStateRow(
        localTable: localTable ?? this.localTable,
        rowKey: rowKey ?? this.rowKey,
        keyJson: keyJson ?? this.keyJson,
        rowHash: rowHash ?? this.rowHash,
        serverVersion:
            serverVersion.present ? serverVersion.value : this.serverVersion,
        status: status ?? this.status,
        rejectedHash:
            rejectedHash.present ? rejectedHash.value : this.rejectedHash,
        lastError: lastError.present ? lastError.value : this.lastError,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  SyncRowStateRow copyWithCompanion(SyncRowStatesCompanion data) {
    return SyncRowStateRow(
      localTable:
          data.localTable.present ? data.localTable.value : this.localTable,
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      keyJson: data.keyJson.present ? data.keyJson.value : this.keyJson,
      rowHash: data.rowHash.present ? data.rowHash.value : this.rowHash,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      status: data.status.present ? data.status.value : this.status,
      rejectedHash: data.rejectedHash.present
          ? data.rejectedHash.value
          : this.rejectedHash,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRowStateRow(')
          ..write('localTable: $localTable, ')
          ..write('rowKey: $rowKey, ')
          ..write('keyJson: $keyJson, ')
          ..write('rowHash: $rowHash, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('status: $status, ')
          ..write('rejectedHash: $rejectedHash, ')
          ..write('lastError: $lastError, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localTable, rowKey, keyJson, rowHash,
      serverVersion, status, rejectedHash, lastError, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRowStateRow &&
          other.localTable == this.localTable &&
          other.rowKey == this.rowKey &&
          other.keyJson == this.keyJson &&
          other.rowHash == this.rowHash &&
          other.serverVersion == this.serverVersion &&
          other.status == this.status &&
          other.rejectedHash == this.rejectedHash &&
          other.lastError == this.lastError &&
          other.syncedAt == this.syncedAt);
}

class SyncRowStatesCompanion extends UpdateCompanion<SyncRowStateRow> {
  final Value<String> localTable;
  final Value<String> rowKey;
  final Value<String> keyJson;
  final Value<String> rowHash;
  final Value<String?> serverVersion;
  final Value<String> status;
  final Value<String?> rejectedHash;
  final Value<String?> lastError;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const SyncRowStatesCompanion({
    this.localTable = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.keyJson = const Value.absent(),
    this.rowHash = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.rejectedHash = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRowStatesCompanion.insert({
    required String localTable,
    required String rowKey,
    required String keyJson,
    required String rowHash,
    this.serverVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.rejectedHash = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  })  : localTable = Value(localTable),
        rowKey = Value(rowKey),
        keyJson = Value(keyJson),
        rowHash = Value(rowHash),
        syncedAt = Value(syncedAt);
  static Insertable<SyncRowStateRow> custom({
    Expression<String>? localTable,
    Expression<String>? rowKey,
    Expression<String>? keyJson,
    Expression<String>? rowHash,
    Expression<String>? serverVersion,
    Expression<String>? status,
    Expression<String>? rejectedHash,
    Expression<String>? lastError,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localTable != null) 'local_table': localTable,
      if (rowKey != null) 'row_key': rowKey,
      if (keyJson != null) 'key_json': keyJson,
      if (rowHash != null) 'row_hash': rowHash,
      if (serverVersion != null) 'server_version': serverVersion,
      if (status != null) 'status': status,
      if (rejectedHash != null) 'rejected_hash': rejectedHash,
      if (lastError != null) 'last_error': lastError,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRowStatesCompanion copyWith(
      {Value<String>? localTable,
      Value<String>? rowKey,
      Value<String>? keyJson,
      Value<String>? rowHash,
      Value<String?>? serverVersion,
      Value<String>? status,
      Value<String?>? rejectedHash,
      Value<String?>? lastError,
      Value<DateTime>? syncedAt,
      Value<int>? rowid}) {
    return SyncRowStatesCompanion(
      localTable: localTable ?? this.localTable,
      rowKey: rowKey ?? this.rowKey,
      keyJson: keyJson ?? this.keyJson,
      rowHash: rowHash ?? this.rowHash,
      serverVersion: serverVersion ?? this.serverVersion,
      status: status ?? this.status,
      rejectedHash: rejectedHash ?? this.rejectedHash,
      lastError: lastError ?? this.lastError,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localTable.present) {
      map['local_table'] = Variable<String>(localTable.value);
    }
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (keyJson.present) {
      map['key_json'] = Variable<String>(keyJson.value);
    }
    if (rowHash.present) {
      map['row_hash'] = Variable<String>(rowHash.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<String>(serverVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rejectedHash.present) {
      map['rejected_hash'] = Variable<String>(rejectedHash.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRowStatesCompanion(')
          ..write('localTable: $localTable, ')
          ..write('rowKey: $rowKey, ')
          ..write('keyJson: $keyJson, ')
          ..write('rowHash: $rowHash, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('status: $status, ')
          ..write('rejectedHash: $rejectedHash, ')
          ..write('lastError: $lastError, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OrdersTable orders = $OrdersTable(this);
  late final $OrderLinesTable orderLines = $OrderLinesTable(this);
  late final $PendingUploadIntentsTable pendingUploadIntents =
      $PendingUploadIntentsTable(this);
  late final $KitchenTicketsTable kitchenTickets = $KitchenTicketsTable(this);
  late final $ShiftsTable shifts = $ShiftsTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $DeviceSessionsTable deviceSessions = $DeviceSessionsTable(this);
  late final $RestaurantTablesTable restaurantTables =
      $RestaurantTablesTable(this);
  late final $AllOrdersTableTable allOrdersTable = $AllOrdersTableTable(this);
  late final $MenuCategoriesTableTable menuCategoriesTable =
      $MenuCategoriesTableTable(this);
  late final $MenuItemsTableTable menuItemsTable = $MenuItemsTableTable(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final $RawMaterialsTableTable rawMaterialsTable =
      $RawMaterialsTableTable(this);
  late final $SuppliersTableTable suppliersTable = $SuppliersTableTable(this);
  late final $SupplierPricesTableTable supplierPricesTable =
      $SupplierPricesTableTable(this);
  late final $PurchaseOrdersTableTable purchaseOrdersTable =
      $PurchaseOrdersTableTable(this);
  late final $PurchaseOrderLinesTableTable purchaseOrderLinesTable =
      $PurchaseOrderLinesTableTable(this);
  late final $GoodsReceiptsTableTable goodsReceiptsTable =
      $GoodsReceiptsTableTable(this);
  late final $StockMovementsTableTable stockMovementsTable =
      $StockMovementsTableTable(this);
  late final $OffersTableTable offersTable = $OffersTableTable(this);
  late final $MediaAssetsTableTable mediaAssetsTable =
      $MediaAssetsTableTable(this);
  late final $RecipesTableTable recipesTable = $RecipesTableTable(this);
  late final $RecipeLinesTableTable recipeLinesTable =
      $RecipeLinesTableTable(this);
  late final $DeliveriesTableTable deliveriesTable =
      $DeliveriesTableTable(this);
  late final $ReservationsTableTable reservationsTable =
      $ReservationsTableTable(this);
  late final $QrCodesTableTable qrCodesTable = $QrCodesTableTable(this);
  late final $QrSessionsTableTable qrSessionsTable =
      $QrSessionsTableTable(this);
  late final $SyncRowStatesTable syncRowStates = $SyncRowStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        orders,
        orderLines,
        pendingUploadIntents,
        kitchenTickets,
        shifts,
        payments,
        deviceSessions,
        restaurantTables,
        allOrdersTable,
        menuCategoriesTable,
        menuItemsTable,
        appMetadata,
        rawMaterialsTable,
        suppliersTable,
        supplierPricesTable,
        purchaseOrdersTable,
        purchaseOrderLinesTable,
        goodsReceiptsTable,
        stockMovementsTable,
        offersTable,
        mediaAssetsTable,
        recipesTable,
        recipeLinesTable,
        deliveriesTable,
        reservationsTable,
        qrCodesTable,
        qrSessionsTable,
        syncRowStates
      ];
}

typedef $$OrdersTableCreateCompanionBuilder = OrdersCompanion Function({
  required String clientOrderId,
  required String locationId,
  required String currencyCode,
  required String status,
  required String orderType,
  Value<String?> tableLabel,
  Value<DateTime> createdAt,
  Value<String> opsStatus,
  Value<String> channel,
  Value<String> source,
  Value<int?> guests,
  Value<String> serverName,
  Value<String> notes,
  Value<double> discountPct,
  Value<double> taxPct,
  Value<int?> billNo,
  Value<String?> paymentMethod,
  Value<DateTime?> settledAt,
  Value<String> customerName,
  Value<String?> displayNo,
  Value<int> rowid,
});
typedef $$OrdersTableUpdateCompanionBuilder = OrdersCompanion Function({
  Value<String> clientOrderId,
  Value<String> locationId,
  Value<String> currencyCode,
  Value<String> status,
  Value<String> orderType,
  Value<String?> tableLabel,
  Value<DateTime> createdAt,
  Value<String> opsStatus,
  Value<String> channel,
  Value<String> source,
  Value<int?> guests,
  Value<String> serverName,
  Value<String> notes,
  Value<double> discountPct,
  Value<double> taxPct,
  Value<int?> billNo,
  Value<String?> paymentMethod,
  Value<DateTime?> settledAt,
  Value<String> customerName,
  Value<String?> displayNo,
  Value<int> rowid,
});

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currencyCode => $composableBuilder(
      column: $table.currencyCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderType => $composableBuilder(
      column: $table.orderType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableLabel => $composableBuilder(
      column: $table.tableLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opsStatus => $composableBuilder(
      column: $table.opsStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get guests => $composableBuilder(
      column: $table.guests, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverName => $composableBuilder(
      column: $table.serverName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get discountPct => $composableBuilder(
      column: $table.discountPct, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get taxPct => $composableBuilder(
      column: $table.taxPct, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get billNo => $composableBuilder(
      column: $table.billNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get settledAt => $composableBuilder(
      column: $table.settledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayNo => $composableBuilder(
      column: $table.displayNo, builder: (column) => ColumnFilters(column));
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currencyCode => $composableBuilder(
      column: $table.currencyCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderType => $composableBuilder(
      column: $table.orderType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableLabel => $composableBuilder(
      column: $table.tableLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opsStatus => $composableBuilder(
      column: $table.opsStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get guests => $composableBuilder(
      column: $table.guests, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverName => $composableBuilder(
      column: $table.serverName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get discountPct => $composableBuilder(
      column: $table.discountPct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get taxPct => $composableBuilder(
      column: $table.taxPct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get billNo => $composableBuilder(
      column: $table.billNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get settledAt => $composableBuilder(
      column: $table.settledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayNo => $composableBuilder(
      column: $table.displayNo, builder: (column) => ColumnOrderings(column));
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
      column: $table.currencyCode, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get orderType =>
      $composableBuilder(column: $table.orderType, builder: (column) => column);

  GeneratedColumn<String> get tableLabel => $composableBuilder(
      column: $table.tableLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get opsStatus =>
      $composableBuilder(column: $table.opsStatus, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get guests =>
      $composableBuilder(column: $table.guests, builder: (column) => column);

  GeneratedColumn<String> get serverName => $composableBuilder(
      column: $table.serverName, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get discountPct => $composableBuilder(
      column: $table.discountPct, builder: (column) => column);

  GeneratedColumn<double> get taxPct =>
      $composableBuilder(column: $table.taxPct, builder: (column) => column);

  GeneratedColumn<int> get billNo =>
      $composableBuilder(column: $table.billNo, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<DateTime> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<String> get displayNo =>
      $composableBuilder(column: $table.displayNo, builder: (column) => column);
}

class $$OrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrdersTable,
    OrderRow,
    $$OrdersTableFilterComposer,
    $$OrdersTableOrderingComposer,
    $$OrdersTableAnnotationComposer,
    $$OrdersTableCreateCompanionBuilder,
    $$OrdersTableUpdateCompanionBuilder,
    (OrderRow, BaseReferences<_$AppDatabase, $OrdersTable, OrderRow>),
    OrderRow,
    PrefetchHooks Function()> {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientOrderId = const Value.absent(),
            Value<String> locationId = const Value.absent(),
            Value<String> currencyCode = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> orderType = const Value.absent(),
            Value<String?> tableLabel = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> opsStatus = const Value.absent(),
            Value<String> channel = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int?> guests = const Value.absent(),
            Value<String> serverName = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<double> discountPct = const Value.absent(),
            Value<double> taxPct = const Value.absent(),
            Value<int?> billNo = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            Value<DateTime?> settledAt = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<String?> displayNo = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrdersCompanion(
            clientOrderId: clientOrderId,
            locationId: locationId,
            currencyCode: currencyCode,
            status: status,
            orderType: orderType,
            tableLabel: tableLabel,
            createdAt: createdAt,
            opsStatus: opsStatus,
            channel: channel,
            source: source,
            guests: guests,
            serverName: serverName,
            notes: notes,
            discountPct: discountPct,
            taxPct: taxPct,
            billNo: billNo,
            paymentMethod: paymentMethod,
            settledAt: settledAt,
            customerName: customerName,
            displayNo: displayNo,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientOrderId,
            required String locationId,
            required String currencyCode,
            required String status,
            required String orderType,
            Value<String?> tableLabel = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> opsStatus = const Value.absent(),
            Value<String> channel = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int?> guests = const Value.absent(),
            Value<String> serverName = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<double> discountPct = const Value.absent(),
            Value<double> taxPct = const Value.absent(),
            Value<int?> billNo = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            Value<DateTime?> settledAt = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<String?> displayNo = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrdersCompanion.insert(
            clientOrderId: clientOrderId,
            locationId: locationId,
            currencyCode: currencyCode,
            status: status,
            orderType: orderType,
            tableLabel: tableLabel,
            createdAt: createdAt,
            opsStatus: opsStatus,
            channel: channel,
            source: source,
            guests: guests,
            serverName: serverName,
            notes: notes,
            discountPct: discountPct,
            taxPct: taxPct,
            billNo: billNo,
            paymentMethod: paymentMethod,
            settledAt: settledAt,
            customerName: customerName,
            displayNo: displayNo,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OrdersTable, OrderRow>(table),
                    BaseReferences<_$AppDatabase, $OrdersTable, OrderRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrdersTable,
    OrderRow,
    $$OrdersTableFilterComposer,
    $$OrdersTableOrderingComposer,
    $$OrdersTableAnnotationComposer,
    $$OrdersTableCreateCompanionBuilder,
    $$OrdersTableUpdateCompanionBuilder,
    (OrderRow, BaseReferences<_$AppDatabase, $OrdersTable, OrderRow>),
    OrderRow,
    PrefetchHooks Function()>;
typedef $$OrderLinesTableCreateCompanionBuilder = OrderLinesCompanion Function({
  required String clientOrderId,
  required String itemId,
  required String name,
  required int unitMinor,
  required int quantity,
  Value<String> station,
  Value<bool> isVeg,
  Value<bool> kitchenDone,
  Value<int> rowid,
});
typedef $$OrderLinesTableUpdateCompanionBuilder = OrderLinesCompanion Function({
  Value<String> clientOrderId,
  Value<String> itemId,
  Value<String> name,
  Value<int> unitMinor,
  Value<int> quantity,
  Value<String> station,
  Value<bool> isVeg,
  Value<bool> kitchenDone,
  Value<int> rowid,
});

class $$OrderLinesTableFilterComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitMinor => $composableBuilder(
      column: $table.unitMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get station => $composableBuilder(
      column: $table.station, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVeg => $composableBuilder(
      column: $table.isVeg, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get kitchenDone => $composableBuilder(
      column: $table.kitchenDone, builder: (column) => ColumnFilters(column));
}

class $$OrderLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitMinor => $composableBuilder(
      column: $table.unitMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get station => $composableBuilder(
      column: $table.station, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVeg => $composableBuilder(
      column: $table.isVeg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get kitchenDone => $composableBuilder(
      column: $table.kitchenDone, builder: (column) => ColumnOrderings(column));
}

class $$OrderLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get unitMinor =>
      $composableBuilder(column: $table.unitMinor, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get station =>
      $composableBuilder(column: $table.station, builder: (column) => column);

  GeneratedColumn<bool> get isVeg =>
      $composableBuilder(column: $table.isVeg, builder: (column) => column);

  GeneratedColumn<bool> get kitchenDone => $composableBuilder(
      column: $table.kitchenDone, builder: (column) => column);
}

class $$OrderLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrderLinesTable,
    OrderLineRow,
    $$OrderLinesTableFilterComposer,
    $$OrderLinesTableOrderingComposer,
    $$OrderLinesTableAnnotationComposer,
    $$OrderLinesTableCreateCompanionBuilder,
    $$OrderLinesTableUpdateCompanionBuilder,
    (
      OrderLineRow,
      BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLineRow>
    ),
    OrderLineRow,
    PrefetchHooks Function()> {
  $$OrderLinesTableTableManager(_$AppDatabase db, $OrderLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientOrderId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> unitMinor = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<String> station = const Value.absent(),
            Value<bool> isVeg = const Value.absent(),
            Value<bool> kitchenDone = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrderLinesCompanion(
            clientOrderId: clientOrderId,
            itemId: itemId,
            name: name,
            unitMinor: unitMinor,
            quantity: quantity,
            station: station,
            isVeg: isVeg,
            kitchenDone: kitchenDone,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientOrderId,
            required String itemId,
            required String name,
            required int unitMinor,
            required int quantity,
            Value<String> station = const Value.absent(),
            Value<bool> isVeg = const Value.absent(),
            Value<bool> kitchenDone = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OrderLinesCompanion.insert(
            clientOrderId: clientOrderId,
            itemId: itemId,
            name: name,
            unitMinor: unitMinor,
            quantity: quantity,
            station: station,
            isVeg: isVeg,
            kitchenDone: kitchenDone,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OrderLinesTable, OrderLineRow>(table),
                    BaseReferences<_$AppDatabase, $OrderLinesTable,
                        OrderLineRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OrderLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrderLinesTable,
    OrderLineRow,
    $$OrderLinesTableFilterComposer,
    $$OrderLinesTableOrderingComposer,
    $$OrderLinesTableAnnotationComposer,
    $$OrderLinesTableCreateCompanionBuilder,
    $$OrderLinesTableUpdateCompanionBuilder,
    (
      OrderLineRow,
      BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLineRow>
    ),
    OrderLineRow,
    PrefetchHooks Function()>;
typedef $$PendingUploadIntentsTableCreateCompanionBuilder
    = PendingUploadIntentsCompanion Function({
  required String intentId,
  required String clientOrderId,
  required String operation,
  required String payloadHash,
  Value<String> state,
  Value<int> retryCount,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$PendingUploadIntentsTableUpdateCompanionBuilder
    = PendingUploadIntentsCompanion Function({
  Value<String> intentId,
  Value<String> clientOrderId,
  Value<String> operation,
  Value<String> payloadHash,
  Value<String> state,
  Value<int> retryCount,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PendingUploadIntentsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingUploadIntentsTable> {
  $$PendingUploadIntentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get intentId => $composableBuilder(
      column: $table.intentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadHash => $composableBuilder(
      column: $table.payloadHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingUploadIntentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingUploadIntentsTable> {
  $$PendingUploadIntentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get intentId => $composableBuilder(
      column: $table.intentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadHash => $composableBuilder(
      column: $table.payloadHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingUploadIntentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingUploadIntentsTable> {
  $$PendingUploadIntentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get intentId =>
      $composableBuilder(column: $table.intentId, builder: (column) => column);

  GeneratedColumn<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadHash => $composableBuilder(
      column: $table.payloadHash, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingUploadIntentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingUploadIntentsTable,
    PendingUploadIntentRow,
    $$PendingUploadIntentsTableFilterComposer,
    $$PendingUploadIntentsTableOrderingComposer,
    $$PendingUploadIntentsTableAnnotationComposer,
    $$PendingUploadIntentsTableCreateCompanionBuilder,
    $$PendingUploadIntentsTableUpdateCompanionBuilder,
    (
      PendingUploadIntentRow,
      BaseReferences<_$AppDatabase, $PendingUploadIntentsTable,
          PendingUploadIntentRow>
    ),
    PendingUploadIntentRow,
    PrefetchHooks Function()> {
  $$PendingUploadIntentsTableTableManager(
      _$AppDatabase db, $PendingUploadIntentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingUploadIntentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingUploadIntentsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingUploadIntentsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> intentId = const Value.absent(),
            Value<String> clientOrderId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payloadHash = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingUploadIntentsCompanion(
            intentId: intentId,
            clientOrderId: clientOrderId,
            operation: operation,
            payloadHash: payloadHash,
            state: state,
            retryCount: retryCount,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String intentId,
            required String clientOrderId,
            required String operation,
            required String payloadHash,
            Value<String> state = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingUploadIntentsCompanion.insert(
            intentId: intentId,
            clientOrderId: clientOrderId,
            operation: operation,
            payloadHash: payloadHash,
            state: state,
            retryCount: retryCount,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingUploadIntentsTable,
                        PendingUploadIntentRow>(table),
                    BaseReferences<_$AppDatabase, $PendingUploadIntentsTable,
                        PendingUploadIntentRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingUploadIntentsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PendingUploadIntentsTable,
        PendingUploadIntentRow,
        $$PendingUploadIntentsTableFilterComposer,
        $$PendingUploadIntentsTableOrderingComposer,
        $$PendingUploadIntentsTableAnnotationComposer,
        $$PendingUploadIntentsTableCreateCompanionBuilder,
        $$PendingUploadIntentsTableUpdateCompanionBuilder,
        (
          PendingUploadIntentRow,
          BaseReferences<_$AppDatabase, $PendingUploadIntentsTable,
              PendingUploadIntentRow>
        ),
        PendingUploadIntentRow,
        PrefetchHooks Function()>;
typedef $$KitchenTicketsTableCreateCompanionBuilder = KitchenTicketsCompanion
    Function({
  required String ticketId,
  required String clientOrderId,
  required String status,
  Value<DateTime> createdAt,
  Value<String> notes,
  Value<bool> urgent,
  Value<DateTime?> completedAt,
  Value<int?> kotNo,
  Value<int> rowid,
});
typedef $$KitchenTicketsTableUpdateCompanionBuilder = KitchenTicketsCompanion
    Function({
  Value<String> ticketId,
  Value<String> clientOrderId,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<String> notes,
  Value<bool> urgent,
  Value<DateTime?> completedAt,
  Value<int?> kotNo,
  Value<int> rowid,
});

class $$KitchenTicketsTableFilterComposer
    extends Composer<_$AppDatabase, $KitchenTicketsTable> {
  $$KitchenTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ticketId => $composableBuilder(
      column: $table.ticketId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get urgent => $composableBuilder(
      column: $table.urgent, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get kotNo => $composableBuilder(
      column: $table.kotNo, builder: (column) => ColumnFilters(column));
}

class $$KitchenTicketsTableOrderingComposer
    extends Composer<_$AppDatabase, $KitchenTicketsTable> {
  $$KitchenTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ticketId => $composableBuilder(
      column: $table.ticketId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get urgent => $composableBuilder(
      column: $table.urgent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get kotNo => $composableBuilder(
      column: $table.kotNo, builder: (column) => ColumnOrderings(column));
}

class $$KitchenTicketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KitchenTicketsTable> {
  $$KitchenTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ticketId =>
      $composableBuilder(column: $table.ticketId, builder: (column) => column);

  GeneratedColumn<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get urgent =>
      $composableBuilder(column: $table.urgent, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get kotNo =>
      $composableBuilder(column: $table.kotNo, builder: (column) => column);
}

class $$KitchenTicketsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KitchenTicketsTable,
    KitchenTicketRow,
    $$KitchenTicketsTableFilterComposer,
    $$KitchenTicketsTableOrderingComposer,
    $$KitchenTicketsTableAnnotationComposer,
    $$KitchenTicketsTableCreateCompanionBuilder,
    $$KitchenTicketsTableUpdateCompanionBuilder,
    (
      KitchenTicketRow,
      BaseReferences<_$AppDatabase, $KitchenTicketsTable, KitchenTicketRow>
    ),
    KitchenTicketRow,
    PrefetchHooks Function()> {
  $$KitchenTicketsTableTableManager(
      _$AppDatabase db, $KitchenTicketsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KitchenTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KitchenTicketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KitchenTicketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ticketId = const Value.absent(),
            Value<String> clientOrderId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<bool> urgent = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int?> kotNo = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KitchenTicketsCompanion(
            ticketId: ticketId,
            clientOrderId: clientOrderId,
            status: status,
            createdAt: createdAt,
            notes: notes,
            urgent: urgent,
            completedAt: completedAt,
            kotNo: kotNo,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String ticketId,
            required String clientOrderId,
            required String status,
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<bool> urgent = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int?> kotNo = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KitchenTicketsCompanion.insert(
            ticketId: ticketId,
            clientOrderId: clientOrderId,
            status: status,
            createdAt: createdAt,
            notes: notes,
            urgent: urgent,
            completedAt: completedAt,
            kotNo: kotNo,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$KitchenTicketsTable, KitchenTicketRow>(table),
                    BaseReferences<_$AppDatabase, $KitchenTicketsTable,
                        KitchenTicketRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KitchenTicketsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KitchenTicketsTable,
    KitchenTicketRow,
    $$KitchenTicketsTableFilterComposer,
    $$KitchenTicketsTableOrderingComposer,
    $$KitchenTicketsTableAnnotationComposer,
    $$KitchenTicketsTableCreateCompanionBuilder,
    $$KitchenTicketsTableUpdateCompanionBuilder,
    (
      KitchenTicketRow,
      BaseReferences<_$AppDatabase, $KitchenTicketsTable, KitchenTicketRow>
    ),
    KitchenTicketRow,
    PrefetchHooks Function()>;
typedef $$ShiftsTableCreateCompanionBuilder = ShiftsCompanion Function({
  required String shiftId,
  required String locationId,
  required int openingFloatMinor,
  required DateTime openedAt,
  Value<DateTime?> closedAt,
  Value<int?> countedCashMinor,
  Value<int> rowid,
});
typedef $$ShiftsTableUpdateCompanionBuilder = ShiftsCompanion Function({
  Value<String> shiftId,
  Value<String> locationId,
  Value<int> openingFloatMinor,
  Value<DateTime> openedAt,
  Value<DateTime?> closedAt,
  Value<int?> countedCashMinor,
  Value<int> rowid,
});

class $$ShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get shiftId => $composableBuilder(
      column: $table.shiftId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get openingFloatMinor => $composableBuilder(
      column: $table.openingFloatMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
      column: $table.openedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
      column: $table.closedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get countedCashMinor => $composableBuilder(
      column: $table.countedCashMinor,
      builder: (column) => ColumnFilters(column));
}

class $$ShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get shiftId => $composableBuilder(
      column: $table.shiftId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get openingFloatMinor => $composableBuilder(
      column: $table.openingFloatMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
      column: $table.openedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
      column: $table.closedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get countedCashMinor => $composableBuilder(
      column: $table.countedCashMinor,
      builder: (column) => ColumnOrderings(column));
}

class $$ShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get shiftId =>
      $composableBuilder(column: $table.shiftId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<int> get openingFloatMinor => $composableBuilder(
      column: $table.openingFloatMinor, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get countedCashMinor => $composableBuilder(
      column: $table.countedCashMinor, builder: (column) => column);
}

class $$ShiftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShiftsTable,
    ShiftRow,
    $$ShiftsTableFilterComposer,
    $$ShiftsTableOrderingComposer,
    $$ShiftsTableAnnotationComposer,
    $$ShiftsTableCreateCompanionBuilder,
    $$ShiftsTableUpdateCompanionBuilder,
    (ShiftRow, BaseReferences<_$AppDatabase, $ShiftsTable, ShiftRow>),
    ShiftRow,
    PrefetchHooks Function()> {
  $$ShiftsTableTableManager(_$AppDatabase db, $ShiftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> shiftId = const Value.absent(),
            Value<String> locationId = const Value.absent(),
            Value<int> openingFloatMinor = const Value.absent(),
            Value<DateTime> openedAt = const Value.absent(),
            Value<DateTime?> closedAt = const Value.absent(),
            Value<int?> countedCashMinor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ShiftsCompanion(
            shiftId: shiftId,
            locationId: locationId,
            openingFloatMinor: openingFloatMinor,
            openedAt: openedAt,
            closedAt: closedAt,
            countedCashMinor: countedCashMinor,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String shiftId,
            required String locationId,
            required int openingFloatMinor,
            required DateTime openedAt,
            Value<DateTime?> closedAt = const Value.absent(),
            Value<int?> countedCashMinor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ShiftsCompanion.insert(
            shiftId: shiftId,
            locationId: locationId,
            openingFloatMinor: openingFloatMinor,
            openedAt: openedAt,
            closedAt: closedAt,
            countedCashMinor: countedCashMinor,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ShiftsTable, ShiftRow>(table),
                    BaseReferences<_$AppDatabase, $ShiftsTable, ShiftRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ShiftsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ShiftsTable,
    ShiftRow,
    $$ShiftsTableFilterComposer,
    $$ShiftsTableOrderingComposer,
    $$ShiftsTableAnnotationComposer,
    $$ShiftsTableCreateCompanionBuilder,
    $$ShiftsTableUpdateCompanionBuilder,
    (ShiftRow, BaseReferences<_$AppDatabase, $ShiftsTable, ShiftRow>),
    ShiftRow,
    PrefetchHooks Function()>;
typedef $$PaymentsTableCreateCompanionBuilder = PaymentsCompanion Function({
  required String paymentId,
  required String clientOrderId,
  required String method,
  required int amountMinor,
  required int receivedMinor,
  Value<DateTime> recordedAt,
  Value<int> rowid,
});
typedef $$PaymentsTableUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> paymentId,
  Value<String> clientOrderId,
  Value<String> method,
  Value<int> amountMinor,
  Value<int> receivedMinor,
  Value<DateTime> recordedAt,
  Value<int> rowid,
});

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get paymentId => $composableBuilder(
      column: $table.paymentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get receivedMinor => $composableBuilder(
      column: $table.receivedMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get paymentId => $composableBuilder(
      column: $table.paymentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get receivedMinor => $composableBuilder(
      column: $table.receivedMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get paymentId =>
      $composableBuilder(column: $table.paymentId, builder: (column) => column);

  GeneratedColumn<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<int> get receivedMinor => $composableBuilder(
      column: $table.receivedMinor, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);
}

class $$PaymentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PaymentsTable,
    PaymentRow,
    $$PaymentsTableFilterComposer,
    $$PaymentsTableOrderingComposer,
    $$PaymentsTableAnnotationComposer,
    $$PaymentsTableCreateCompanionBuilder,
    $$PaymentsTableUpdateCompanionBuilder,
    (PaymentRow, BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>),
    PaymentRow,
    PrefetchHooks Function()> {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> paymentId = const Value.absent(),
            Value<String> clientOrderId = const Value.absent(),
            Value<String> method = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<int> receivedMinor = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PaymentsCompanion(
            paymentId: paymentId,
            clientOrderId: clientOrderId,
            method: method,
            amountMinor: amountMinor,
            receivedMinor: receivedMinor,
            recordedAt: recordedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String paymentId,
            required String clientOrderId,
            required String method,
            required int amountMinor,
            required int receivedMinor,
            Value<DateTime> recordedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PaymentsCompanion.insert(
            paymentId: paymentId,
            clientOrderId: clientOrderId,
            method: method,
            amountMinor: amountMinor,
            receivedMinor: receivedMinor,
            recordedAt: recordedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PaymentsTable, PaymentRow>(table),
                    BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PaymentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PaymentsTable,
    PaymentRow,
    $$PaymentsTableFilterComposer,
    $$PaymentsTableOrderingComposer,
    $$PaymentsTableAnnotationComposer,
    $$PaymentsTableCreateCompanionBuilder,
    $$PaymentsTableUpdateCompanionBuilder,
    (PaymentRow, BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>),
    PaymentRow,
    PrefetchHooks Function()>;
typedef $$DeviceSessionsTableCreateCompanionBuilder = DeviceSessionsCompanion
    Function({
  required String deviceId,
  required String staffId,
  required String staffName,
  required String locationId,
  required DateTime grantedAt,
  required DateTime grantExpiresAt,
  Value<int> rowid,
});
typedef $$DeviceSessionsTableUpdateCompanionBuilder = DeviceSessionsCompanion
    Function({
  Value<String> deviceId,
  Value<String> staffId,
  Value<String> staffName,
  Value<String> locationId,
  Value<DateTime> grantedAt,
  Value<DateTime> grantExpiresAt,
  Value<int> rowid,
});

class $$DeviceSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceSessionsTable> {
  $$DeviceSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get staffId => $composableBuilder(
      column: $table.staffId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get staffName => $composableBuilder(
      column: $table.staffName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get grantedAt => $composableBuilder(
      column: $table.grantedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get grantExpiresAt => $composableBuilder(
      column: $table.grantExpiresAt,
      builder: (column) => ColumnFilters(column));
}

class $$DeviceSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceSessionsTable> {
  $$DeviceSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get staffId => $composableBuilder(
      column: $table.staffId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get staffName => $composableBuilder(
      column: $table.staffName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get grantedAt => $composableBuilder(
      column: $table.grantedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get grantExpiresAt => $composableBuilder(
      column: $table.grantExpiresAt,
      builder: (column) => ColumnOrderings(column));
}

class $$DeviceSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceSessionsTable> {
  $$DeviceSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get staffName =>
      $composableBuilder(column: $table.staffName, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<DateTime> get grantedAt =>
      $composableBuilder(column: $table.grantedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get grantExpiresAt => $composableBuilder(
      column: $table.grantExpiresAt, builder: (column) => column);
}

class $$DeviceSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeviceSessionsTable,
    DeviceSessionRow,
    $$DeviceSessionsTableFilterComposer,
    $$DeviceSessionsTableOrderingComposer,
    $$DeviceSessionsTableAnnotationComposer,
    $$DeviceSessionsTableCreateCompanionBuilder,
    $$DeviceSessionsTableUpdateCompanionBuilder,
    (
      DeviceSessionRow,
      BaseReferences<_$AppDatabase, $DeviceSessionsTable, DeviceSessionRow>
    ),
    DeviceSessionRow,
    PrefetchHooks Function()> {
  $$DeviceSessionsTableTableManager(
      _$AppDatabase db, $DeviceSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<String> staffId = const Value.absent(),
            Value<String> staffName = const Value.absent(),
            Value<String> locationId = const Value.absent(),
            Value<DateTime> grantedAt = const Value.absent(),
            Value<DateTime> grantExpiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeviceSessionsCompanion(
            deviceId: deviceId,
            staffId: staffId,
            staffName: staffName,
            locationId: locationId,
            grantedAt: grantedAt,
            grantExpiresAt: grantExpiresAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            required String staffId,
            required String staffName,
            required String locationId,
            required DateTime grantedAt,
            required DateTime grantExpiresAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DeviceSessionsCompanion.insert(
            deviceId: deviceId,
            staffId: staffId,
            staffName: staffName,
            locationId: locationId,
            grantedAt: grantedAt,
            grantExpiresAt: grantExpiresAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DeviceSessionsTable, DeviceSessionRow>(table),
                    BaseReferences<_$AppDatabase, $DeviceSessionsTable,
                        DeviceSessionRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeviceSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeviceSessionsTable,
    DeviceSessionRow,
    $$DeviceSessionsTableFilterComposer,
    $$DeviceSessionsTableOrderingComposer,
    $$DeviceSessionsTableAnnotationComposer,
    $$DeviceSessionsTableCreateCompanionBuilder,
    $$DeviceSessionsTableUpdateCompanionBuilder,
    (
      DeviceSessionRow,
      BaseReferences<_$AppDatabase, $DeviceSessionsTable, DeviceSessionRow>
    ),
    DeviceSessionRow,
    PrefetchHooks Function()>;
typedef $$RestaurantTablesTableCreateCompanionBuilder
    = RestaurantTablesCompanion Function({
  required String id,
  required String label,
  required int seats,
  required String zone,
  required String status,
  Value<int?> guestCount,
  Value<int?> elapsedMinutes,
  Value<int?> orderTotalMinor,
  Value<String?> reservedByName,
  Value<DateTime?> reservedAt,
  Value<DateTime> createdAt,
  Value<String> floor,
  Value<String> shape,
  Value<String> serverName,
  Value<bool> paymentPending,
  Value<String?> currentOrderId,
  Value<DateTime?> seatedAt,
  Value<DateTime?> lastCleanedAt,
  Value<int> rowid,
});
typedef $$RestaurantTablesTableUpdateCompanionBuilder
    = RestaurantTablesCompanion Function({
  Value<String> id,
  Value<String> label,
  Value<int> seats,
  Value<String> zone,
  Value<String> status,
  Value<int?> guestCount,
  Value<int?> elapsedMinutes,
  Value<int?> orderTotalMinor,
  Value<String?> reservedByName,
  Value<DateTime?> reservedAt,
  Value<DateTime> createdAt,
  Value<String> floor,
  Value<String> shape,
  Value<String> serverName,
  Value<bool> paymentPending,
  Value<String?> currentOrderId,
  Value<DateTime?> seatedAt,
  Value<DateTime?> lastCleanedAt,
  Value<int> rowid,
});

class $$RestaurantTablesTableFilterComposer
    extends Composer<_$AppDatabase, $RestaurantTablesTable> {
  $$RestaurantTablesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seats => $composableBuilder(
      column: $table.seats, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get zone => $composableBuilder(
      column: $table.zone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get guestCount => $composableBuilder(
      column: $table.guestCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get elapsedMinutes => $composableBuilder(
      column: $table.elapsedMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderTotalMinor => $composableBuilder(
      column: $table.orderTotalMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reservedByName => $composableBuilder(
      column: $table.reservedByName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reservedAt => $composableBuilder(
      column: $table.reservedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get floor => $composableBuilder(
      column: $table.floor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shape => $composableBuilder(
      column: $table.shape, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverName => $composableBuilder(
      column: $table.serverName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get paymentPending => $composableBuilder(
      column: $table.paymentPending,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currentOrderId => $composableBuilder(
      column: $table.currentOrderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get seatedAt => $composableBuilder(
      column: $table.seatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastCleanedAt => $composableBuilder(
      column: $table.lastCleanedAt, builder: (column) => ColumnFilters(column));
}

class $$RestaurantTablesTableOrderingComposer
    extends Composer<_$AppDatabase, $RestaurantTablesTable> {
  $$RestaurantTablesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seats => $composableBuilder(
      column: $table.seats, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get zone => $composableBuilder(
      column: $table.zone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get guestCount => $composableBuilder(
      column: $table.guestCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get elapsedMinutes => $composableBuilder(
      column: $table.elapsedMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderTotalMinor => $composableBuilder(
      column: $table.orderTotalMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reservedByName => $composableBuilder(
      column: $table.reservedByName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reservedAt => $composableBuilder(
      column: $table.reservedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get floor => $composableBuilder(
      column: $table.floor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shape => $composableBuilder(
      column: $table.shape, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverName => $composableBuilder(
      column: $table.serverName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get paymentPending => $composableBuilder(
      column: $table.paymentPending,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currentOrderId => $composableBuilder(
      column: $table.currentOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get seatedAt => $composableBuilder(
      column: $table.seatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastCleanedAt => $composableBuilder(
      column: $table.lastCleanedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$RestaurantTablesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestaurantTablesTable> {
  $$RestaurantTablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get seats =>
      $composableBuilder(column: $table.seats, builder: (column) => column);

  GeneratedColumn<String> get zone =>
      $composableBuilder(column: $table.zone, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get guestCount => $composableBuilder(
      column: $table.guestCount, builder: (column) => column);

  GeneratedColumn<int> get elapsedMinutes => $composableBuilder(
      column: $table.elapsedMinutes, builder: (column) => column);

  GeneratedColumn<int> get orderTotalMinor => $composableBuilder(
      column: $table.orderTotalMinor, builder: (column) => column);

  GeneratedColumn<String> get reservedByName => $composableBuilder(
      column: $table.reservedByName, builder: (column) => column);

  GeneratedColumn<DateTime> get reservedAt => $composableBuilder(
      column: $table.reservedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get floor =>
      $composableBuilder(column: $table.floor, builder: (column) => column);

  GeneratedColumn<String> get shape =>
      $composableBuilder(column: $table.shape, builder: (column) => column);

  GeneratedColumn<String> get serverName => $composableBuilder(
      column: $table.serverName, builder: (column) => column);

  GeneratedColumn<bool> get paymentPending => $composableBuilder(
      column: $table.paymentPending, builder: (column) => column);

  GeneratedColumn<String> get currentOrderId => $composableBuilder(
      column: $table.currentOrderId, builder: (column) => column);

  GeneratedColumn<DateTime> get seatedAt =>
      $composableBuilder(column: $table.seatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCleanedAt => $composableBuilder(
      column: $table.lastCleanedAt, builder: (column) => column);
}

class $$RestaurantTablesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RestaurantTablesTable,
    RestaurantTableRow,
    $$RestaurantTablesTableFilterComposer,
    $$RestaurantTablesTableOrderingComposer,
    $$RestaurantTablesTableAnnotationComposer,
    $$RestaurantTablesTableCreateCompanionBuilder,
    $$RestaurantTablesTableUpdateCompanionBuilder,
    (
      RestaurantTableRow,
      BaseReferences<_$AppDatabase, $RestaurantTablesTable, RestaurantTableRow>
    ),
    RestaurantTableRow,
    PrefetchHooks Function()> {
  $$RestaurantTablesTableTableManager(
      _$AppDatabase db, $RestaurantTablesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestaurantTablesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestaurantTablesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestaurantTablesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<int> seats = const Value.absent(),
            Value<String> zone = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> guestCount = const Value.absent(),
            Value<int?> elapsedMinutes = const Value.absent(),
            Value<int?> orderTotalMinor = const Value.absent(),
            Value<String?> reservedByName = const Value.absent(),
            Value<DateTime?> reservedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> floor = const Value.absent(),
            Value<String> shape = const Value.absent(),
            Value<String> serverName = const Value.absent(),
            Value<bool> paymentPending = const Value.absent(),
            Value<String?> currentOrderId = const Value.absent(),
            Value<DateTime?> seatedAt = const Value.absent(),
            Value<DateTime?> lastCleanedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RestaurantTablesCompanion(
            id: id,
            label: label,
            seats: seats,
            zone: zone,
            status: status,
            guestCount: guestCount,
            elapsedMinutes: elapsedMinutes,
            orderTotalMinor: orderTotalMinor,
            reservedByName: reservedByName,
            reservedAt: reservedAt,
            createdAt: createdAt,
            floor: floor,
            shape: shape,
            serverName: serverName,
            paymentPending: paymentPending,
            currentOrderId: currentOrderId,
            seatedAt: seatedAt,
            lastCleanedAt: lastCleanedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String label,
            required int seats,
            required String zone,
            required String status,
            Value<int?> guestCount = const Value.absent(),
            Value<int?> elapsedMinutes = const Value.absent(),
            Value<int?> orderTotalMinor = const Value.absent(),
            Value<String?> reservedByName = const Value.absent(),
            Value<DateTime?> reservedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> floor = const Value.absent(),
            Value<String> shape = const Value.absent(),
            Value<String> serverName = const Value.absent(),
            Value<bool> paymentPending = const Value.absent(),
            Value<String?> currentOrderId = const Value.absent(),
            Value<DateTime?> seatedAt = const Value.absent(),
            Value<DateTime?> lastCleanedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RestaurantTablesCompanion.insert(
            id: id,
            label: label,
            seats: seats,
            zone: zone,
            status: status,
            guestCount: guestCount,
            elapsedMinutes: elapsedMinutes,
            orderTotalMinor: orderTotalMinor,
            reservedByName: reservedByName,
            reservedAt: reservedAt,
            createdAt: createdAt,
            floor: floor,
            shape: shape,
            serverName: serverName,
            paymentPending: paymentPending,
            currentOrderId: currentOrderId,
            seatedAt: seatedAt,
            lastCleanedAt: lastCleanedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RestaurantTablesTable, RestaurantTableRow>(
                        table),
                    BaseReferences<_$AppDatabase, $RestaurantTablesTable,
                        RestaurantTableRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RestaurantTablesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RestaurantTablesTable,
    RestaurantTableRow,
    $$RestaurantTablesTableFilterComposer,
    $$RestaurantTablesTableOrderingComposer,
    $$RestaurantTablesTableAnnotationComposer,
    $$RestaurantTablesTableCreateCompanionBuilder,
    $$RestaurantTablesTableUpdateCompanionBuilder,
    (
      RestaurantTableRow,
      BaseReferences<_$AppDatabase, $RestaurantTablesTable, RestaurantTableRow>
    ),
    RestaurantTableRow,
    PrefetchHooks Function()>;
typedef $$AllOrdersTableTableCreateCompanionBuilder = AllOrdersTableCompanion
    Function({
  required String orderId,
  required String type,
  required String source,
  required String tableOrCustomer,
  required String itemsLabel,
  required int amountMinor,
  required String status,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$AllOrdersTableTableUpdateCompanionBuilder = AllOrdersTableCompanion
    Function({
  Value<String> orderId,
  Value<String> type,
  Value<String> source,
  Value<String> tableOrCustomer,
  Value<String> itemsLabel,
  Value<int> amountMinor,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AllOrdersTableTableFilterComposer
    extends Composer<_$AppDatabase, $AllOrdersTableTable> {
  $$AllOrdersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableOrCustomer => $composableBuilder(
      column: $table.tableOrCustomer,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemsLabel => $composableBuilder(
      column: $table.itemsLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AllOrdersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AllOrdersTableTable> {
  $$AllOrdersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableOrCustomer => $composableBuilder(
      column: $table.tableOrCustomer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemsLabel => $composableBuilder(
      column: $table.itemsLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AllOrdersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AllOrdersTableTable> {
  $$AllOrdersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get tableOrCustomer => $composableBuilder(
      column: $table.tableOrCustomer, builder: (column) => column);

  GeneratedColumn<String> get itemsLabel => $composableBuilder(
      column: $table.itemsLabel, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AllOrdersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AllOrdersTableTable,
    AllOrderEntity,
    $$AllOrdersTableTableFilterComposer,
    $$AllOrdersTableTableOrderingComposer,
    $$AllOrdersTableTableAnnotationComposer,
    $$AllOrdersTableTableCreateCompanionBuilder,
    $$AllOrdersTableTableUpdateCompanionBuilder,
    (
      AllOrderEntity,
      BaseReferences<_$AppDatabase, $AllOrdersTableTable, AllOrderEntity>
    ),
    AllOrderEntity,
    PrefetchHooks Function()> {
  $$AllOrdersTableTableTableManager(
      _$AppDatabase db, $AllOrdersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllOrdersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AllOrdersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AllOrdersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> orderId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> tableOrCustomer = const Value.absent(),
            Value<String> itemsLabel = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AllOrdersTableCompanion(
            orderId: orderId,
            type: type,
            source: source,
            tableOrCustomer: tableOrCustomer,
            itemsLabel: itemsLabel,
            amountMinor: amountMinor,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String orderId,
            required String type,
            required String source,
            required String tableOrCustomer,
            required String itemsLabel,
            required int amountMinor,
            required String status,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AllOrdersTableCompanion.insert(
            orderId: orderId,
            type: type,
            source: source,
            tableOrCustomer: tableOrCustomer,
            itemsLabel: itemsLabel,
            amountMinor: amountMinor,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AllOrdersTableTable, AllOrderEntity>(table),
                    BaseReferences<_$AppDatabase, $AllOrdersTableTable,
                        AllOrderEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AllOrdersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AllOrdersTableTable,
    AllOrderEntity,
    $$AllOrdersTableTableFilterComposer,
    $$AllOrdersTableTableOrderingComposer,
    $$AllOrdersTableTableAnnotationComposer,
    $$AllOrdersTableTableCreateCompanionBuilder,
    $$AllOrdersTableTableUpdateCompanionBuilder,
    (
      AllOrderEntity,
      BaseReferences<_$AppDatabase, $AllOrdersTableTable, AllOrderEntity>
    ),
    AllOrderEntity,
    PrefetchHooks Function()>;
typedef $$MenuCategoriesTableTableCreateCompanionBuilder
    = MenuCategoriesTableCompanion Function({
  required String id,
  required String name,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$MenuCategoriesTableTableUpdateCompanionBuilder
    = MenuCategoriesTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$MenuCategoriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MenuCategoriesTableTable> {
  $$MenuCategoriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MenuCategoriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MenuCategoriesTableTable> {
  $$MenuCategoriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MenuCategoriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MenuCategoriesTableTable> {
  $$MenuCategoriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MenuCategoriesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MenuCategoriesTableTable,
    MenuCategoryEntity,
    $$MenuCategoriesTableTableFilterComposer,
    $$MenuCategoriesTableTableOrderingComposer,
    $$MenuCategoriesTableTableAnnotationComposer,
    $$MenuCategoriesTableTableCreateCompanionBuilder,
    $$MenuCategoriesTableTableUpdateCompanionBuilder,
    (
      MenuCategoryEntity,
      BaseReferences<_$AppDatabase, $MenuCategoriesTableTable,
          MenuCategoryEntity>
    ),
    MenuCategoryEntity,
    PrefetchHooks Function()> {
  $$MenuCategoriesTableTableTableManager(
      _$AppDatabase db, $MenuCategoriesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MenuCategoriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MenuCategoriesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MenuCategoriesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MenuCategoriesTableCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MenuCategoriesTableCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MenuCategoriesTableTable, MenuCategoryEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $MenuCategoriesTableTable,
                        MenuCategoryEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MenuCategoriesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MenuCategoriesTableTable,
    MenuCategoryEntity,
    $$MenuCategoriesTableTableFilterComposer,
    $$MenuCategoriesTableTableOrderingComposer,
    $$MenuCategoriesTableTableAnnotationComposer,
    $$MenuCategoriesTableTableCreateCompanionBuilder,
    $$MenuCategoriesTableTableUpdateCompanionBuilder,
    (
      MenuCategoryEntity,
      BaseReferences<_$AppDatabase, $MenuCategoriesTableTable,
          MenuCategoryEntity>
    ),
    MenuCategoryEntity,
    PrefetchHooks Function()>;
typedef $$MenuItemsTableTableCreateCompanionBuilder = MenuItemsTableCompanion
    Function({
  required String id,
  required String categoryId,
  required String name,
  required int priceMinor,
  Value<bool> isVeg,
  Value<bool> isBestseller,
  Value<bool> available,
  Value<String?> unavailableReason,
  Value<DateTime> createdAt,
  Value<String> sku,
  Value<String> hsn,
  Value<int> foodCostMinor,
  Value<String> channels,
  Value<String> kitchenStation,
  Value<String> menuStatus,
  Value<String> availabilityLabel,
  Value<String> imageUrl,
  Value<String> dietType,
  Value<String> detailsJson,
  Value<int> rowid,
});
typedef $$MenuItemsTableTableUpdateCompanionBuilder = MenuItemsTableCompanion
    Function({
  Value<String> id,
  Value<String> categoryId,
  Value<String> name,
  Value<int> priceMinor,
  Value<bool> isVeg,
  Value<bool> isBestseller,
  Value<bool> available,
  Value<String?> unavailableReason,
  Value<DateTime> createdAt,
  Value<String> sku,
  Value<String> hsn,
  Value<int> foodCostMinor,
  Value<String> channels,
  Value<String> kitchenStation,
  Value<String> menuStatus,
  Value<String> availabilityLabel,
  Value<String> imageUrl,
  Value<String> dietType,
  Value<String> detailsJson,
  Value<int> rowid,
});

class $$MenuItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $MenuItemsTableTable> {
  $$MenuItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVeg => $composableBuilder(
      column: $table.isVeg, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isBestseller => $composableBuilder(
      column: $table.isBestseller, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get available => $composableBuilder(
      column: $table.available, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unavailableReason => $composableBuilder(
      column: $table.unavailableReason,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hsn => $composableBuilder(
      column: $table.hsn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get foodCostMinor => $composableBuilder(
      column: $table.foodCostMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channels => $composableBuilder(
      column: $table.channels, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kitchenStation => $composableBuilder(
      column: $table.kitchenStation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get menuStatus => $composableBuilder(
      column: $table.menuStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get availabilityLabel => $composableBuilder(
      column: $table.availabilityLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dietType => $composableBuilder(
      column: $table.dietType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => ColumnFilters(column));
}

class $$MenuItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MenuItemsTableTable> {
  $$MenuItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVeg => $composableBuilder(
      column: $table.isVeg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isBestseller => $composableBuilder(
      column: $table.isBestseller,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get available => $composableBuilder(
      column: $table.available, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unavailableReason => $composableBuilder(
      column: $table.unavailableReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hsn => $composableBuilder(
      column: $table.hsn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get foodCostMinor => $composableBuilder(
      column: $table.foodCostMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channels => $composableBuilder(
      column: $table.channels, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kitchenStation => $composableBuilder(
      column: $table.kitchenStation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get menuStatus => $composableBuilder(
      column: $table.menuStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get availabilityLabel => $composableBuilder(
      column: $table.availabilityLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dietType => $composableBuilder(
      column: $table.dietType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => ColumnOrderings(column));
}

class $$MenuItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MenuItemsTableTable> {
  $$MenuItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => column);

  GeneratedColumn<bool> get isVeg =>
      $composableBuilder(column: $table.isVeg, builder: (column) => column);

  GeneratedColumn<bool> get isBestseller => $composableBuilder(
      column: $table.isBestseller, builder: (column) => column);

  GeneratedColumn<bool> get available =>
      $composableBuilder(column: $table.available, builder: (column) => column);

  GeneratedColumn<String> get unavailableReason => $composableBuilder(
      column: $table.unavailableReason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get hsn =>
      $composableBuilder(column: $table.hsn, builder: (column) => column);

  GeneratedColumn<int> get foodCostMinor => $composableBuilder(
      column: $table.foodCostMinor, builder: (column) => column);

  GeneratedColumn<String> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<String> get kitchenStation => $composableBuilder(
      column: $table.kitchenStation, builder: (column) => column);

  GeneratedColumn<String> get menuStatus => $composableBuilder(
      column: $table.menuStatus, builder: (column) => column);

  GeneratedColumn<String> get availabilityLabel => $composableBuilder(
      column: $table.availabilityLabel, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get dietType =>
      $composableBuilder(column: $table.dietType, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => column);
}

class $$MenuItemsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MenuItemsTableTable,
    MenuItemEntity,
    $$MenuItemsTableTableFilterComposer,
    $$MenuItemsTableTableOrderingComposer,
    $$MenuItemsTableTableAnnotationComposer,
    $$MenuItemsTableTableCreateCompanionBuilder,
    $$MenuItemsTableTableUpdateCompanionBuilder,
    (
      MenuItemEntity,
      BaseReferences<_$AppDatabase, $MenuItemsTableTable, MenuItemEntity>
    ),
    MenuItemEntity,
    PrefetchHooks Function()> {
  $$MenuItemsTableTableTableManager(
      _$AppDatabase db, $MenuItemsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MenuItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MenuItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MenuItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> priceMinor = const Value.absent(),
            Value<bool> isVeg = const Value.absent(),
            Value<bool> isBestseller = const Value.absent(),
            Value<bool> available = const Value.absent(),
            Value<String?> unavailableReason = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> sku = const Value.absent(),
            Value<String> hsn = const Value.absent(),
            Value<int> foodCostMinor = const Value.absent(),
            Value<String> channels = const Value.absent(),
            Value<String> kitchenStation = const Value.absent(),
            Value<String> menuStatus = const Value.absent(),
            Value<String> availabilityLabel = const Value.absent(),
            Value<String> imageUrl = const Value.absent(),
            Value<String> dietType = const Value.absent(),
            Value<String> detailsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MenuItemsTableCompanion(
            id: id,
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            isVeg: isVeg,
            isBestseller: isBestseller,
            available: available,
            unavailableReason: unavailableReason,
            createdAt: createdAt,
            sku: sku,
            hsn: hsn,
            foodCostMinor: foodCostMinor,
            channels: channels,
            kitchenStation: kitchenStation,
            menuStatus: menuStatus,
            availabilityLabel: availabilityLabel,
            imageUrl: imageUrl,
            dietType: dietType,
            detailsJson: detailsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String categoryId,
            required String name,
            required int priceMinor,
            Value<bool> isVeg = const Value.absent(),
            Value<bool> isBestseller = const Value.absent(),
            Value<bool> available = const Value.absent(),
            Value<String?> unavailableReason = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> sku = const Value.absent(),
            Value<String> hsn = const Value.absent(),
            Value<int> foodCostMinor = const Value.absent(),
            Value<String> channels = const Value.absent(),
            Value<String> kitchenStation = const Value.absent(),
            Value<String> menuStatus = const Value.absent(),
            Value<String> availabilityLabel = const Value.absent(),
            Value<String> imageUrl = const Value.absent(),
            Value<String> dietType = const Value.absent(),
            Value<String> detailsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MenuItemsTableCompanion.insert(
            id: id,
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            isVeg: isVeg,
            isBestseller: isBestseller,
            available: available,
            unavailableReason: unavailableReason,
            createdAt: createdAt,
            sku: sku,
            hsn: hsn,
            foodCostMinor: foodCostMinor,
            channels: channels,
            kitchenStation: kitchenStation,
            menuStatus: menuStatus,
            availabilityLabel: availabilityLabel,
            imageUrl: imageUrl,
            dietType: dietType,
            detailsJson: detailsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MenuItemsTableTable, MenuItemEntity>(table),
                    BaseReferences<_$AppDatabase, $MenuItemsTableTable,
                        MenuItemEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MenuItemsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MenuItemsTableTable,
    MenuItemEntity,
    $$MenuItemsTableTableFilterComposer,
    $$MenuItemsTableTableOrderingComposer,
    $$MenuItemsTableTableAnnotationComposer,
    $$MenuItemsTableTableCreateCompanionBuilder,
    $$MenuItemsTableTableUpdateCompanionBuilder,
    (
      MenuItemEntity,
      BaseReferences<_$AppDatabase, $MenuItemsTableTable, MenuItemEntity>
    ),
    MenuItemEntity,
    PrefetchHooks Function()>;
typedef $$AppMetadataTableCreateCompanionBuilder = AppMetadataCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetadataTableUpdateCompanionBuilder = AppMetadataCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetadataTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppMetadataTable,
    AppMetadataRow,
    $$AppMetadataTableFilterComposer,
    $$AppMetadataTableOrderingComposer,
    $$AppMetadataTableAnnotationComposer,
    $$AppMetadataTableCreateCompanionBuilder,
    $$AppMetadataTableUpdateCompanionBuilder,
    (
      AppMetadataRow,
      BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataRow>
    ),
    AppMetadataRow,
    PrefetchHooks Function()> {
  $$AppMetadataTableTableManager(_$AppDatabase db, $AppMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetadataCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetadataCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AppMetadataTable, AppMetadataRow>(table),
                    BaseReferences<_$AppDatabase, $AppMetadataTable,
                        AppMetadataRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppMetadataTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppMetadataTable,
    AppMetadataRow,
    $$AppMetadataTableFilterComposer,
    $$AppMetadataTableOrderingComposer,
    $$AppMetadataTableAnnotationComposer,
    $$AppMetadataTableCreateCompanionBuilder,
    $$AppMetadataTableUpdateCompanionBuilder,
    (
      AppMetadataRow,
      BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataRow>
    ),
    AppMetadataRow,
    PrefetchHooks Function()>;
typedef $$RawMaterialsTableTableCreateCompanionBuilder
    = RawMaterialsTableCompanion Function({
  required String id,
  required String code,
  required String name,
  required String category,
  required String unit,
  Value<double> stockQty,
  Value<double> reorderLevel,
  Value<double> maxCapacity,
  Value<double> purchaseCost,
  Value<double?> lastPurchasePrice,
  Value<String?> preferredSupplierId,
  Value<String> hsn,
  Value<String> emoji,
  Value<int> leadTimeDays,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$RawMaterialsTableTableUpdateCompanionBuilder
    = RawMaterialsTableCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<String> category,
  Value<String> unit,
  Value<double> stockQty,
  Value<double> reorderLevel,
  Value<double> maxCapacity,
  Value<double> purchaseCost,
  Value<double?> lastPurchasePrice,
  Value<String?> preferredSupplierId,
  Value<String> hsn,
  Value<String> emoji,
  Value<int> leadTimeDays,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$RawMaterialsTableTableFilterComposer
    extends Composer<_$AppDatabase, $RawMaterialsTableTable> {
  $$RawMaterialsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get reorderLevel => $composableBuilder(
      column: $table.reorderLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get maxCapacity => $composableBuilder(
      column: $table.maxCapacity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get purchaseCost => $composableBuilder(
      column: $table.purchaseCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lastPurchasePrice => $composableBuilder(
      column: $table.lastPurchasePrice,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferredSupplierId => $composableBuilder(
      column: $table.preferredSupplierId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hsn => $composableBuilder(
      column: $table.hsn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leadTimeDays => $composableBuilder(
      column: $table.leadTimeDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$RawMaterialsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RawMaterialsTableTable> {
  $$RawMaterialsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get reorderLevel => $composableBuilder(
      column: $table.reorderLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get maxCapacity => $composableBuilder(
      column: $table.maxCapacity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get purchaseCost => $composableBuilder(
      column: $table.purchaseCost,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lastPurchasePrice => $composableBuilder(
      column: $table.lastPurchasePrice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferredSupplierId => $composableBuilder(
      column: $table.preferredSupplierId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hsn => $composableBuilder(
      column: $table.hsn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leadTimeDays => $composableBuilder(
      column: $table.leadTimeDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$RawMaterialsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RawMaterialsTableTable> {
  $$RawMaterialsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<double> get reorderLevel => $composableBuilder(
      column: $table.reorderLevel, builder: (column) => column);

  GeneratedColumn<double> get maxCapacity => $composableBuilder(
      column: $table.maxCapacity, builder: (column) => column);

  GeneratedColumn<double> get purchaseCost => $composableBuilder(
      column: $table.purchaseCost, builder: (column) => column);

  GeneratedColumn<double> get lastPurchasePrice => $composableBuilder(
      column: $table.lastPurchasePrice, builder: (column) => column);

  GeneratedColumn<String> get preferredSupplierId => $composableBuilder(
      column: $table.preferredSupplierId, builder: (column) => column);

  GeneratedColumn<String> get hsn =>
      $composableBuilder(column: $table.hsn, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get leadTimeDays => $composableBuilder(
      column: $table.leadTimeDays, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RawMaterialsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RawMaterialsTableTable,
    RawMaterialEntity,
    $$RawMaterialsTableTableFilterComposer,
    $$RawMaterialsTableTableOrderingComposer,
    $$RawMaterialsTableTableAnnotationComposer,
    $$RawMaterialsTableTableCreateCompanionBuilder,
    $$RawMaterialsTableTableUpdateCompanionBuilder,
    (
      RawMaterialEntity,
      BaseReferences<_$AppDatabase, $RawMaterialsTableTable, RawMaterialEntity>
    ),
    RawMaterialEntity,
    PrefetchHooks Function()> {
  $$RawMaterialsTableTableTableManager(
      _$AppDatabase db, $RawMaterialsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RawMaterialsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RawMaterialsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RawMaterialsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> stockQty = const Value.absent(),
            Value<double> reorderLevel = const Value.absent(),
            Value<double> maxCapacity = const Value.absent(),
            Value<double> purchaseCost = const Value.absent(),
            Value<double?> lastPurchasePrice = const Value.absent(),
            Value<String?> preferredSupplierId = const Value.absent(),
            Value<String> hsn = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<int> leadTimeDays = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RawMaterialsTableCompanion(
            id: id,
            code: code,
            name: name,
            category: category,
            unit: unit,
            stockQty: stockQty,
            reorderLevel: reorderLevel,
            maxCapacity: maxCapacity,
            purchaseCost: purchaseCost,
            lastPurchasePrice: lastPurchasePrice,
            preferredSupplierId: preferredSupplierId,
            hsn: hsn,
            emoji: emoji,
            leadTimeDays: leadTimeDays,
            active: active,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String code,
            required String name,
            required String category,
            required String unit,
            Value<double> stockQty = const Value.absent(),
            Value<double> reorderLevel = const Value.absent(),
            Value<double> maxCapacity = const Value.absent(),
            Value<double> purchaseCost = const Value.absent(),
            Value<double?> lastPurchasePrice = const Value.absent(),
            Value<String?> preferredSupplierId = const Value.absent(),
            Value<String> hsn = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<int> leadTimeDays = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RawMaterialsTableCompanion.insert(
            id: id,
            code: code,
            name: name,
            category: category,
            unit: unit,
            stockQty: stockQty,
            reorderLevel: reorderLevel,
            maxCapacity: maxCapacity,
            purchaseCost: purchaseCost,
            lastPurchasePrice: lastPurchasePrice,
            preferredSupplierId: preferredSupplierId,
            hsn: hsn,
            emoji: emoji,
            leadTimeDays: leadTimeDays,
            active: active,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RawMaterialsTableTable, RawMaterialEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $RawMaterialsTableTable,
                        RawMaterialEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RawMaterialsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RawMaterialsTableTable,
    RawMaterialEntity,
    $$RawMaterialsTableTableFilterComposer,
    $$RawMaterialsTableTableOrderingComposer,
    $$RawMaterialsTableTableAnnotationComposer,
    $$RawMaterialsTableTableCreateCompanionBuilder,
    $$RawMaterialsTableTableUpdateCompanionBuilder,
    (
      RawMaterialEntity,
      BaseReferences<_$AppDatabase, $RawMaterialsTableTable, RawMaterialEntity>
    ),
    RawMaterialEntity,
    PrefetchHooks Function()>;
typedef $$SuppliersTableTableCreateCompanionBuilder = SuppliersTableCompanion
    Function({
  required String id,
  required String name,
  Value<String> legalName,
  Value<String> category,
  Value<String> contactPerson,
  Value<String> phone,
  Value<String> email,
  Value<String> gstin,
  Value<String> city,
  Value<double> rating,
  Value<String> paymentTerms,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$SuppliersTableTableUpdateCompanionBuilder = SuppliersTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> legalName,
  Value<String> category,
  Value<String> contactPerson,
  Value<String> phone,
  Value<String> email,
  Value<String> gstin,
  Value<String> city,
  Value<double> rating,
  Value<String> paymentTerms,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$SuppliersTableTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTableTable> {
  $$SuppliersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get legalName => $composableBuilder(
      column: $table.legalName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactPerson => $composableBuilder(
      column: $table.contactPerson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gstin => $composableBuilder(
      column: $table.gstin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentTerms => $composableBuilder(
      column: $table.paymentTerms, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SuppliersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTableTable> {
  $$SuppliersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get legalName => $composableBuilder(
      column: $table.legalName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactPerson => $composableBuilder(
      column: $table.contactPerson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gstin => $composableBuilder(
      column: $table.gstin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentTerms => $composableBuilder(
      column: $table.paymentTerms,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SuppliersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTableTable> {
  $$SuppliersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get legalName =>
      $composableBuilder(column: $table.legalName, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get contactPerson => $composableBuilder(
      column: $table.contactPerson, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get paymentTerms => $composableBuilder(
      column: $table.paymentTerms, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SuppliersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SuppliersTableTable,
    SupplierEntity,
    $$SuppliersTableTableFilterComposer,
    $$SuppliersTableTableOrderingComposer,
    $$SuppliersTableTableAnnotationComposer,
    $$SuppliersTableTableCreateCompanionBuilder,
    $$SuppliersTableTableUpdateCompanionBuilder,
    (
      SupplierEntity,
      BaseReferences<_$AppDatabase, $SuppliersTableTable, SupplierEntity>
    ),
    SupplierEntity,
    PrefetchHooks Function()> {
  $$SuppliersTableTableTableManager(
      _$AppDatabase db, $SuppliersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> legalName = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> contactPerson = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> gstin = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<double> rating = const Value.absent(),
            Value<String> paymentTerms = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersTableCompanion(
            id: id,
            name: name,
            legalName: legalName,
            category: category,
            contactPerson: contactPerson,
            phone: phone,
            email: email,
            gstin: gstin,
            city: city,
            rating: rating,
            paymentTerms: paymentTerms,
            active: active,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> legalName = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> contactPerson = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> gstin = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<double> rating = const Value.absent(),
            Value<String> paymentTerms = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersTableCompanion.insert(
            id: id,
            name: name,
            legalName: legalName,
            category: category,
            contactPerson: contactPerson,
            phone: phone,
            email: email,
            gstin: gstin,
            city: city,
            rating: rating,
            paymentTerms: paymentTerms,
            active: active,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SuppliersTableTable, SupplierEntity>(table),
                    BaseReferences<_$AppDatabase, $SuppliersTableTable,
                        SupplierEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SuppliersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SuppliersTableTable,
    SupplierEntity,
    $$SuppliersTableTableFilterComposer,
    $$SuppliersTableTableOrderingComposer,
    $$SuppliersTableTableAnnotationComposer,
    $$SuppliersTableTableCreateCompanionBuilder,
    $$SuppliersTableTableUpdateCompanionBuilder,
    (
      SupplierEntity,
      BaseReferences<_$AppDatabase, $SuppliersTableTable, SupplierEntity>
    ),
    SupplierEntity,
    PrefetchHooks Function()>;
typedef $$SupplierPricesTableTableCreateCompanionBuilder
    = SupplierPricesTableCompanion Function({
  required String id,
  required String ingredientName,
  Value<String?> materialId,
  Value<String> emoji,
  Value<String> linkedTo,
  required String supplierId,
  required String unit,
  required double lastPrice,
  required double currentPrice,
  required double lowestWeek,
  required String source,
  Value<String> priority,
  Value<String> skuId,
  Value<bool> approved,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$SupplierPricesTableTableUpdateCompanionBuilder
    = SupplierPricesTableCompanion Function({
  Value<String> id,
  Value<String> ingredientName,
  Value<String?> materialId,
  Value<String> emoji,
  Value<String> linkedTo,
  Value<String> supplierId,
  Value<String> unit,
  Value<double> lastPrice,
  Value<double> currentPrice,
  Value<double> lowestWeek,
  Value<String> source,
  Value<String> priority,
  Value<String> skuId,
  Value<bool> approved,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SupplierPricesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SupplierPricesTableTable> {
  $$SupplierPricesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ingredientName => $composableBuilder(
      column: $table.ingredientName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get linkedTo => $composableBuilder(
      column: $table.linkedTo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lastPrice => $composableBuilder(
      column: $table.lastPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get currentPrice => $composableBuilder(
      column: $table.currentPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lowestWeek => $composableBuilder(
      column: $table.lowestWeek, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skuId => $composableBuilder(
      column: $table.skuId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get approved => $composableBuilder(
      column: $table.approved, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SupplierPricesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SupplierPricesTableTable> {
  $$SupplierPricesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ingredientName => $composableBuilder(
      column: $table.ingredientName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get linkedTo => $composableBuilder(
      column: $table.linkedTo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lastPrice => $composableBuilder(
      column: $table.lastPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get currentPrice => $composableBuilder(
      column: $table.currentPrice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lowestWeek => $composableBuilder(
      column: $table.lowestWeek, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skuId => $composableBuilder(
      column: $table.skuId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get approved => $composableBuilder(
      column: $table.approved, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SupplierPricesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SupplierPricesTableTable> {
  $$SupplierPricesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ingredientName => $composableBuilder(
      column: $table.ingredientName, builder: (column) => column);

  GeneratedColumn<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get linkedTo =>
      $composableBuilder(column: $table.linkedTo, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get lastPrice =>
      $composableBuilder(column: $table.lastPrice, builder: (column) => column);

  GeneratedColumn<double> get currentPrice => $composableBuilder(
      column: $table.currentPrice, builder: (column) => column);

  GeneratedColumn<double> get lowestWeek => $composableBuilder(
      column: $table.lowestWeek, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get skuId =>
      $composableBuilder(column: $table.skuId, builder: (column) => column);

  GeneratedColumn<bool> get approved =>
      $composableBuilder(column: $table.approved, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SupplierPricesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SupplierPricesTableTable,
    SupplierPriceEntity,
    $$SupplierPricesTableTableFilterComposer,
    $$SupplierPricesTableTableOrderingComposer,
    $$SupplierPricesTableTableAnnotationComposer,
    $$SupplierPricesTableTableCreateCompanionBuilder,
    $$SupplierPricesTableTableUpdateCompanionBuilder,
    (
      SupplierPriceEntity,
      BaseReferences<_$AppDatabase, $SupplierPricesTableTable,
          SupplierPriceEntity>
    ),
    SupplierPriceEntity,
    PrefetchHooks Function()> {
  $$SupplierPricesTableTableTableManager(
      _$AppDatabase db, $SupplierPricesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SupplierPricesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SupplierPricesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SupplierPricesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> ingredientName = const Value.absent(),
            Value<String?> materialId = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<String> linkedTo = const Value.absent(),
            Value<String> supplierId = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> lastPrice = const Value.absent(),
            Value<double> currentPrice = const Value.absent(),
            Value<double> lowestWeek = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<String> skuId = const Value.absent(),
            Value<bool> approved = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SupplierPricesTableCompanion(
            id: id,
            ingredientName: ingredientName,
            materialId: materialId,
            emoji: emoji,
            linkedTo: linkedTo,
            supplierId: supplierId,
            unit: unit,
            lastPrice: lastPrice,
            currentPrice: currentPrice,
            lowestWeek: lowestWeek,
            source: source,
            priority: priority,
            skuId: skuId,
            approved: approved,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String ingredientName,
            Value<String?> materialId = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<String> linkedTo = const Value.absent(),
            required String supplierId,
            required String unit,
            required double lastPrice,
            required double currentPrice,
            required double lowestWeek,
            required String source,
            Value<String> priority = const Value.absent(),
            Value<String> skuId = const Value.absent(),
            Value<bool> approved = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SupplierPricesTableCompanion.insert(
            id: id,
            ingredientName: ingredientName,
            materialId: materialId,
            emoji: emoji,
            linkedTo: linkedTo,
            supplierId: supplierId,
            unit: unit,
            lastPrice: lastPrice,
            currentPrice: currentPrice,
            lowestWeek: lowestWeek,
            source: source,
            priority: priority,
            skuId: skuId,
            approved: approved,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SupplierPricesTableTable, SupplierPriceEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $SupplierPricesTableTable,
                        SupplierPriceEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SupplierPricesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SupplierPricesTableTable,
    SupplierPriceEntity,
    $$SupplierPricesTableTableFilterComposer,
    $$SupplierPricesTableTableOrderingComposer,
    $$SupplierPricesTableTableAnnotationComposer,
    $$SupplierPricesTableTableCreateCompanionBuilder,
    $$SupplierPricesTableTableUpdateCompanionBuilder,
    (
      SupplierPriceEntity,
      BaseReferences<_$AppDatabase, $SupplierPricesTableTable,
          SupplierPriceEntity>
    ),
    SupplierPriceEntity,
    PrefetchHooks Function()>;
typedef $$PurchaseOrdersTableTableCreateCompanionBuilder
    = PurchaseOrdersTableCompanion Function({
  required String number,
  required String supplierId,
  required DateTime orderDate,
  required DateTime expectedDelivery,
  required String status,
  Value<String> createdBy,
  Value<String> deliveryAddress,
  Value<String> deliveryCity,
  Value<double> taxPct,
  Value<String> notes,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$PurchaseOrdersTableTableUpdateCompanionBuilder
    = PurchaseOrdersTableCompanion Function({
  Value<String> number,
  Value<String> supplierId,
  Value<DateTime> orderDate,
  Value<DateTime> expectedDelivery,
  Value<String> status,
  Value<String> createdBy,
  Value<String> deliveryAddress,
  Value<String> deliveryCity,
  Value<double> taxPct,
  Value<String> notes,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PurchaseOrdersTableTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTableTable> {
  $$PurchaseOrdersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get orderDate => $composableBuilder(
      column: $table.orderDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expectedDelivery => $composableBuilder(
      column: $table.expectedDelivery,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deliveryAddress => $composableBuilder(
      column: $table.deliveryAddress,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deliveryCity => $composableBuilder(
      column: $table.deliveryCity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get taxPct => $composableBuilder(
      column: $table.taxPct, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PurchaseOrdersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTableTable> {
  $$PurchaseOrdersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get orderDate => $composableBuilder(
      column: $table.orderDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expectedDelivery => $composableBuilder(
      column: $table.expectedDelivery,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deliveryAddress => $composableBuilder(
      column: $table.deliveryAddress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deliveryCity => $composableBuilder(
      column: $table.deliveryCity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get taxPct => $composableBuilder(
      column: $table.taxPct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PurchaseOrdersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTableTable> {
  $$PurchaseOrdersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => column);

  GeneratedColumn<DateTime> get orderDate =>
      $composableBuilder(column: $table.orderDate, builder: (column) => column);

  GeneratedColumn<DateTime> get expectedDelivery => $composableBuilder(
      column: $table.expectedDelivery, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get deliveryAddress => $composableBuilder(
      column: $table.deliveryAddress, builder: (column) => column);

  GeneratedColumn<String> get deliveryCity => $composableBuilder(
      column: $table.deliveryCity, builder: (column) => column);

  GeneratedColumn<double> get taxPct =>
      $composableBuilder(column: $table.taxPct, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PurchaseOrdersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseOrdersTableTable,
    PurchaseOrderEntity,
    $$PurchaseOrdersTableTableFilterComposer,
    $$PurchaseOrdersTableTableOrderingComposer,
    $$PurchaseOrdersTableTableAnnotationComposer,
    $$PurchaseOrdersTableTableCreateCompanionBuilder,
    $$PurchaseOrdersTableTableUpdateCompanionBuilder,
    (
      PurchaseOrderEntity,
      BaseReferences<_$AppDatabase, $PurchaseOrdersTableTable,
          PurchaseOrderEntity>
    ),
    PurchaseOrderEntity,
    PrefetchHooks Function()> {
  $$PurchaseOrdersTableTableTableManager(
      _$AppDatabase db, $PurchaseOrdersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseOrdersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseOrdersTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseOrdersTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> number = const Value.absent(),
            Value<String> supplierId = const Value.absent(),
            Value<DateTime> orderDate = const Value.absent(),
            Value<DateTime> expectedDelivery = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> createdBy = const Value.absent(),
            Value<String> deliveryAddress = const Value.absent(),
            Value<String> deliveryCity = const Value.absent(),
            Value<double> taxPct = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrdersTableCompanion(
            number: number,
            supplierId: supplierId,
            orderDate: orderDate,
            expectedDelivery: expectedDelivery,
            status: status,
            createdBy: createdBy,
            deliveryAddress: deliveryAddress,
            deliveryCity: deliveryCity,
            taxPct: taxPct,
            notes: notes,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String number,
            required String supplierId,
            required DateTime orderDate,
            required DateTime expectedDelivery,
            required String status,
            Value<String> createdBy = const Value.absent(),
            Value<String> deliveryAddress = const Value.absent(),
            Value<String> deliveryCity = const Value.absent(),
            Value<double> taxPct = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrdersTableCompanion.insert(
            number: number,
            supplierId: supplierId,
            orderDate: orderDate,
            expectedDelivery: expectedDelivery,
            status: status,
            createdBy: createdBy,
            deliveryAddress: deliveryAddress,
            deliveryCity: deliveryCity,
            taxPct: taxPct,
            notes: notes,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PurchaseOrdersTableTable, PurchaseOrderEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $PurchaseOrdersTableTable,
                        PurchaseOrderEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchaseOrdersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PurchaseOrdersTableTable,
    PurchaseOrderEntity,
    $$PurchaseOrdersTableTableFilterComposer,
    $$PurchaseOrdersTableTableOrderingComposer,
    $$PurchaseOrdersTableTableAnnotationComposer,
    $$PurchaseOrdersTableTableCreateCompanionBuilder,
    $$PurchaseOrdersTableTableUpdateCompanionBuilder,
    (
      PurchaseOrderEntity,
      BaseReferences<_$AppDatabase, $PurchaseOrdersTableTable,
          PurchaseOrderEntity>
    ),
    PurchaseOrderEntity,
    PrefetchHooks Function()>;
typedef $$PurchaseOrderLinesTableTableCreateCompanionBuilder
    = PurchaseOrderLinesTableCompanion Function({
  Value<int> id,
  required String poNumber,
  Value<String?> materialId,
  required String materialName,
  Value<String> code,
  required String unit,
  required double unitCost,
  required double orderedQty,
  Value<double> receivedQty,
  Value<double> rejectedQty,
});
typedef $$PurchaseOrderLinesTableTableUpdateCompanionBuilder
    = PurchaseOrderLinesTableCompanion Function({
  Value<int> id,
  Value<String> poNumber,
  Value<String?> materialId,
  Value<String> materialName,
  Value<String> code,
  Value<String> unit,
  Value<double> unitCost,
  Value<double> orderedQty,
  Value<double> receivedQty,
  Value<double> rejectedQty,
});

class $$PurchaseOrderLinesTableTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseOrderLinesTableTable> {
  $$PurchaseOrderLinesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get poNumber => $composableBuilder(
      column: $table.poNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get materialName => $composableBuilder(
      column: $table.materialName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitCost => $composableBuilder(
      column: $table.unitCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get orderedQty => $composableBuilder(
      column: $table.orderedQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get receivedQty => $composableBuilder(
      column: $table.receivedQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rejectedQty => $composableBuilder(
      column: $table.rejectedQty, builder: (column) => ColumnFilters(column));
}

class $$PurchaseOrderLinesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseOrderLinesTableTable> {
  $$PurchaseOrderLinesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get poNumber => $composableBuilder(
      column: $table.poNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get materialName => $composableBuilder(
      column: $table.materialName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitCost => $composableBuilder(
      column: $table.unitCost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get orderedQty => $composableBuilder(
      column: $table.orderedQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get receivedQty => $composableBuilder(
      column: $table.receivedQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rejectedQty => $composableBuilder(
      column: $table.rejectedQty, builder: (column) => ColumnOrderings(column));
}

class $$PurchaseOrderLinesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseOrderLinesTableTable> {
  $$PurchaseOrderLinesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poNumber =>
      $composableBuilder(column: $table.poNumber, builder: (column) => column);

  GeneratedColumn<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => column);

  GeneratedColumn<String> get materialName => $composableBuilder(
      column: $table.materialName, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<double> get orderedQty => $composableBuilder(
      column: $table.orderedQty, builder: (column) => column);

  GeneratedColumn<double> get receivedQty => $composableBuilder(
      column: $table.receivedQty, builder: (column) => column);

  GeneratedColumn<double> get rejectedQty => $composableBuilder(
      column: $table.rejectedQty, builder: (column) => column);
}

class $$PurchaseOrderLinesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseOrderLinesTableTable,
    PurchaseOrderLineEntity,
    $$PurchaseOrderLinesTableTableFilterComposer,
    $$PurchaseOrderLinesTableTableOrderingComposer,
    $$PurchaseOrderLinesTableTableAnnotationComposer,
    $$PurchaseOrderLinesTableTableCreateCompanionBuilder,
    $$PurchaseOrderLinesTableTableUpdateCompanionBuilder,
    (
      PurchaseOrderLineEntity,
      BaseReferences<_$AppDatabase, $PurchaseOrderLinesTableTable,
          PurchaseOrderLineEntity>
    ),
    PurchaseOrderLineEntity,
    PrefetchHooks Function()> {
  $$PurchaseOrderLinesTableTableTableManager(
      _$AppDatabase db, $PurchaseOrderLinesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseOrderLinesTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseOrderLinesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseOrderLinesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> poNumber = const Value.absent(),
            Value<String?> materialId = const Value.absent(),
            Value<String> materialName = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> unitCost = const Value.absent(),
            Value<double> orderedQty = const Value.absent(),
            Value<double> receivedQty = const Value.absent(),
            Value<double> rejectedQty = const Value.absent(),
          }) =>
              PurchaseOrderLinesTableCompanion(
            id: id,
            poNumber: poNumber,
            materialId: materialId,
            materialName: materialName,
            code: code,
            unit: unit,
            unitCost: unitCost,
            orderedQty: orderedQty,
            receivedQty: receivedQty,
            rejectedQty: rejectedQty,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String poNumber,
            Value<String?> materialId = const Value.absent(),
            required String materialName,
            Value<String> code = const Value.absent(),
            required String unit,
            required double unitCost,
            required double orderedQty,
            Value<double> receivedQty = const Value.absent(),
            Value<double> rejectedQty = const Value.absent(),
          }) =>
              PurchaseOrderLinesTableCompanion.insert(
            id: id,
            poNumber: poNumber,
            materialId: materialId,
            materialName: materialName,
            code: code,
            unit: unit,
            unitCost: unitCost,
            orderedQty: orderedQty,
            receivedQty: receivedQty,
            rejectedQty: rejectedQty,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PurchaseOrderLinesTableTable,
                        PurchaseOrderLineEntity>(table),
                    BaseReferences<_$AppDatabase, $PurchaseOrderLinesTableTable,
                        PurchaseOrderLineEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchaseOrderLinesTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PurchaseOrderLinesTableTable,
        PurchaseOrderLineEntity,
        $$PurchaseOrderLinesTableTableFilterComposer,
        $$PurchaseOrderLinesTableTableOrderingComposer,
        $$PurchaseOrderLinesTableTableAnnotationComposer,
        $$PurchaseOrderLinesTableTableCreateCompanionBuilder,
        $$PurchaseOrderLinesTableTableUpdateCompanionBuilder,
        (
          PurchaseOrderLineEntity,
          BaseReferences<_$AppDatabase, $PurchaseOrderLinesTableTable,
              PurchaseOrderLineEntity>
        ),
        PurchaseOrderLineEntity,
        PrefetchHooks Function()>;
typedef $$GoodsReceiptsTableTableCreateCompanionBuilder
    = GoodsReceiptsTableCompanion Function({
  required String id,
  required String poNumber,
  required DateTime receivedAt,
  required double subtotal,
  required double tax,
  required double total,
  Value<String> notes,
  Value<int> rowid,
});
typedef $$GoodsReceiptsTableTableUpdateCompanionBuilder
    = GoodsReceiptsTableCompanion Function({
  Value<String> id,
  Value<String> poNumber,
  Value<DateTime> receivedAt,
  Value<double> subtotal,
  Value<double> tax,
  Value<double> total,
  Value<String> notes,
  Value<int> rowid,
});

class $$GoodsReceiptsTableTableFilterComposer
    extends Composer<_$AppDatabase, $GoodsReceiptsTableTable> {
  $$GoodsReceiptsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get poNumber => $composableBuilder(
      column: $table.poNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get subtotal => $composableBuilder(
      column: $table.subtotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get tax => $composableBuilder(
      column: $table.tax, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get total => $composableBuilder(
      column: $table.total, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$GoodsReceiptsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GoodsReceiptsTableTable> {
  $$GoodsReceiptsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get poNumber => $composableBuilder(
      column: $table.poNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get subtotal => $composableBuilder(
      column: $table.subtotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get tax => $composableBuilder(
      column: $table.tax, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get total => $composableBuilder(
      column: $table.total, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$GoodsReceiptsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoodsReceiptsTableTable> {
  $$GoodsReceiptsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poNumber =>
      $composableBuilder(column: $table.poNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$GoodsReceiptsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GoodsReceiptsTableTable,
    GoodsReceiptEntity,
    $$GoodsReceiptsTableTableFilterComposer,
    $$GoodsReceiptsTableTableOrderingComposer,
    $$GoodsReceiptsTableTableAnnotationComposer,
    $$GoodsReceiptsTableTableCreateCompanionBuilder,
    $$GoodsReceiptsTableTableUpdateCompanionBuilder,
    (
      GoodsReceiptEntity,
      BaseReferences<_$AppDatabase, $GoodsReceiptsTableTable,
          GoodsReceiptEntity>
    ),
    GoodsReceiptEntity,
    PrefetchHooks Function()> {
  $$GoodsReceiptsTableTableTableManager(
      _$AppDatabase db, $GoodsReceiptsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoodsReceiptsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoodsReceiptsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoodsReceiptsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> poNumber = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<double> subtotal = const Value.absent(),
            Value<double> tax = const Value.absent(),
            Value<double> total = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GoodsReceiptsTableCompanion(
            id: id,
            poNumber: poNumber,
            receivedAt: receivedAt,
            subtotal: subtotal,
            tax: tax,
            total: total,
            notes: notes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String poNumber,
            required DateTime receivedAt,
            required double subtotal,
            required double tax,
            required double total,
            Value<String> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GoodsReceiptsTableCompanion.insert(
            id: id,
            poNumber: poNumber,
            receivedAt: receivedAt,
            subtotal: subtotal,
            tax: tax,
            total: total,
            notes: notes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$GoodsReceiptsTableTable, GoodsReceiptEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $GoodsReceiptsTableTable,
                        GoodsReceiptEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GoodsReceiptsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GoodsReceiptsTableTable,
    GoodsReceiptEntity,
    $$GoodsReceiptsTableTableFilterComposer,
    $$GoodsReceiptsTableTableOrderingComposer,
    $$GoodsReceiptsTableTableAnnotationComposer,
    $$GoodsReceiptsTableTableCreateCompanionBuilder,
    $$GoodsReceiptsTableTableUpdateCompanionBuilder,
    (
      GoodsReceiptEntity,
      BaseReferences<_$AppDatabase, $GoodsReceiptsTableTable,
          GoodsReceiptEntity>
    ),
    GoodsReceiptEntity,
    PrefetchHooks Function()>;
typedef $$StockMovementsTableTableCreateCompanionBuilder
    = StockMovementsTableCompanion Function({
  Value<int> id,
  required String materialId,
  required double qtyDelta,
  required String reason,
  Value<String> reference,
  Value<double?> unitCost,
  Value<DateTime> createdAt,
});
typedef $$StockMovementsTableTableUpdateCompanionBuilder
    = StockMovementsTableCompanion Function({
  Value<int> id,
  Value<String> materialId,
  Value<double> qtyDelta,
  Value<String> reason,
  Value<String> reference,
  Value<double?> unitCost,
  Value<DateTime> createdAt,
});

class $$StockMovementsTableTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovementsTableTable> {
  $$StockMovementsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qtyDelta => $composableBuilder(
      column: $table.qtyDelta, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitCost => $composableBuilder(
      column: $table.unitCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$StockMovementsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovementsTableTable> {
  $$StockMovementsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qtyDelta => $composableBuilder(
      column: $table.qtyDelta, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitCost => $composableBuilder(
      column: $table.unitCost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$StockMovementsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovementsTableTable> {
  $$StockMovementsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => column);

  GeneratedColumn<double> get qtyDelta =>
      $composableBuilder(column: $table.qtyDelta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<double> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StockMovementsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockMovementsTableTable,
    StockMovementEntity,
    $$StockMovementsTableTableFilterComposer,
    $$StockMovementsTableTableOrderingComposer,
    $$StockMovementsTableTableAnnotationComposer,
    $$StockMovementsTableTableCreateCompanionBuilder,
    $$StockMovementsTableTableUpdateCompanionBuilder,
    (
      StockMovementEntity,
      BaseReferences<_$AppDatabase, $StockMovementsTableTable,
          StockMovementEntity>
    ),
    StockMovementEntity,
    PrefetchHooks Function()> {
  $$StockMovementsTableTableTableManager(
      _$AppDatabase db, $StockMovementsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovementsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovementsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovementsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> materialId = const Value.absent(),
            Value<double> qtyDelta = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String> reference = const Value.absent(),
            Value<double?> unitCost = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              StockMovementsTableCompanion(
            id: id,
            materialId: materialId,
            qtyDelta: qtyDelta,
            reason: reason,
            reference: reference,
            unitCost: unitCost,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String materialId,
            required double qtyDelta,
            required String reason,
            Value<String> reference = const Value.absent(),
            Value<double?> unitCost = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              StockMovementsTableCompanion.insert(
            id: id,
            materialId: materialId,
            qtyDelta: qtyDelta,
            reason: reason,
            reference: reference,
            unitCost: unitCost,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$StockMovementsTableTable, StockMovementEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $StockMovementsTableTable,
                        StockMovementEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StockMovementsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockMovementsTableTable,
    StockMovementEntity,
    $$StockMovementsTableTableFilterComposer,
    $$StockMovementsTableTableOrderingComposer,
    $$StockMovementsTableTableAnnotationComposer,
    $$StockMovementsTableTableCreateCompanionBuilder,
    $$StockMovementsTableTableUpdateCompanionBuilder,
    (
      StockMovementEntity,
      BaseReferences<_$AppDatabase, $StockMovementsTableTable,
          StockMovementEntity>
    ),
    StockMovementEntity,
    PrefetchHooks Function()>;
typedef $$OffersTableTableCreateCompanionBuilder = OffersTableCompanion
    Function({
  required String id,
  required String title,
  required String code,
  required String campaignType,
  required String discountRule,
  Value<double> minOrder,
  Value<double> maxDiscount,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  Value<String> channels,
  Value<String> linkedItems,
  required String status,
  Value<int> usageCount,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$OffersTableTableUpdateCompanionBuilder = OffersTableCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> code,
  Value<String> campaignType,
  Value<String> discountRule,
  Value<double> minOrder,
  Value<double> maxDiscount,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  Value<String> channels,
  Value<String> linkedItems,
  Value<String> status,
  Value<int> usageCount,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$OffersTableTableFilterComposer
    extends Composer<_$AppDatabase, $OffersTableTable> {
  $$OffersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get campaignType => $composableBuilder(
      column: $table.campaignType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get discountRule => $composableBuilder(
      column: $table.discountRule, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get minOrder => $composableBuilder(
      column: $table.minOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get maxDiscount => $composableBuilder(
      column: $table.maxDiscount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channels => $composableBuilder(
      column: $table.channels, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get linkedItems => $composableBuilder(
      column: $table.linkedItems, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get usageCount => $composableBuilder(
      column: $table.usageCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$OffersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $OffersTableTable> {
  $$OffersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get campaignType => $composableBuilder(
      column: $table.campaignType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get discountRule => $composableBuilder(
      column: $table.discountRule,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get minOrder => $composableBuilder(
      column: $table.minOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get maxDiscount => $composableBuilder(
      column: $table.maxDiscount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channels => $composableBuilder(
      column: $table.channels, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get linkedItems => $composableBuilder(
      column: $table.linkedItems, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get usageCount => $composableBuilder(
      column: $table.usageCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OffersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $OffersTableTable> {
  $$OffersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get campaignType => $composableBuilder(
      column: $table.campaignType, builder: (column) => column);

  GeneratedColumn<String> get discountRule => $composableBuilder(
      column: $table.discountRule, builder: (column) => column);

  GeneratedColumn<double> get minOrder =>
      $composableBuilder(column: $table.minOrder, builder: (column) => column);

  GeneratedColumn<double> get maxDiscount => $composableBuilder(
      column: $table.maxDiscount, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<String> get linkedItems => $composableBuilder(
      column: $table.linkedItems, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get usageCount => $composableBuilder(
      column: $table.usageCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OffersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OffersTableTable,
    OfferEntity,
    $$OffersTableTableFilterComposer,
    $$OffersTableTableOrderingComposer,
    $$OffersTableTableAnnotationComposer,
    $$OffersTableTableCreateCompanionBuilder,
    $$OffersTableTableUpdateCompanionBuilder,
    (
      OfferEntity,
      BaseReferences<_$AppDatabase, $OffersTableTable, OfferEntity>
    ),
    OfferEntity,
    PrefetchHooks Function()> {
  $$OffersTableTableTableManager(_$AppDatabase db, $OffersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OffersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OffersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OffersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> campaignType = const Value.absent(),
            Value<String> discountRule = const Value.absent(),
            Value<double> minOrder = const Value.absent(),
            Value<double> maxDiscount = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<String> channels = const Value.absent(),
            Value<String> linkedItems = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> usageCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OffersTableCompanion(
            id: id,
            title: title,
            code: code,
            campaignType: campaignType,
            discountRule: discountRule,
            minOrder: minOrder,
            maxDiscount: maxDiscount,
            startDate: startDate,
            endDate: endDate,
            channels: channels,
            linkedItems: linkedItems,
            status: status,
            usageCount: usageCount,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String code,
            required String campaignType,
            required String discountRule,
            Value<double> minOrder = const Value.absent(),
            Value<double> maxDiscount = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<String> channels = const Value.absent(),
            Value<String> linkedItems = const Value.absent(),
            required String status,
            Value<int> usageCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OffersTableCompanion.insert(
            id: id,
            title: title,
            code: code,
            campaignType: campaignType,
            discountRule: discountRule,
            minOrder: minOrder,
            maxDiscount: maxDiscount,
            startDate: startDate,
            endDate: endDate,
            channels: channels,
            linkedItems: linkedItems,
            status: status,
            usageCount: usageCount,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OffersTableTable, OfferEntity>(table),
                    BaseReferences<_$AppDatabase, $OffersTableTable,
                        OfferEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OffersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OffersTableTable,
    OfferEntity,
    $$OffersTableTableFilterComposer,
    $$OffersTableTableOrderingComposer,
    $$OffersTableTableAnnotationComposer,
    $$OffersTableTableCreateCompanionBuilder,
    $$OffersTableTableUpdateCompanionBuilder,
    (
      OfferEntity,
      BaseReferences<_$AppDatabase, $OffersTableTable, OfferEntity>
    ),
    OfferEntity,
    PrefetchHooks Function()>;
typedef $$MediaAssetsTableTableCreateCompanionBuilder
    = MediaAssetsTableCompanion Function({
  required String id,
  required String fileName,
  required String fileType,
  Value<int> sizeBytes,
  required String folder,
  Value<String> usageLabel,
  Value<String?> imageUrl,
  Value<Uint8List?> bytes,
  Value<bool> archived,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$MediaAssetsTableTableUpdateCompanionBuilder
    = MediaAssetsTableCompanion Function({
  Value<String> id,
  Value<String> fileName,
  Value<String> fileType,
  Value<int> sizeBytes,
  Value<String> folder,
  Value<String> usageLabel,
  Value<String?> imageUrl,
  Value<Uint8List?> bytes,
  Value<bool> archived,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$MediaAssetsTableTableFilterComposer
    extends Composer<_$AppDatabase, $MediaAssetsTableTable> {
  $$MediaAssetsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileType => $composableBuilder(
      column: $table.fileType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folder => $composableBuilder(
      column: $table.folder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get usageLabel => $composableBuilder(
      column: $table.usageLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MediaAssetsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaAssetsTableTable> {
  $$MediaAssetsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileType => $composableBuilder(
      column: $table.fileType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folder => $composableBuilder(
      column: $table.folder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get usageLabel => $composableBuilder(
      column: $table.usageLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MediaAssetsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaAssetsTableTable> {
  $$MediaAssetsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get usageLabel => $composableBuilder(
      column: $table.usageLabel, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MediaAssetsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaAssetsTableTable,
    MediaAssetEntity,
    $$MediaAssetsTableTableFilterComposer,
    $$MediaAssetsTableTableOrderingComposer,
    $$MediaAssetsTableTableAnnotationComposer,
    $$MediaAssetsTableTableCreateCompanionBuilder,
    $$MediaAssetsTableTableUpdateCompanionBuilder,
    (
      MediaAssetEntity,
      BaseReferences<_$AppDatabase, $MediaAssetsTableTable, MediaAssetEntity>
    ),
    MediaAssetEntity,
    PrefetchHooks Function()> {
  $$MediaAssetsTableTableTableManager(
      _$AppDatabase db, $MediaAssetsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaAssetsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaAssetsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaAssetsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<String> fileType = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<String> folder = const Value.absent(),
            Value<String> usageLabel = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<Uint8List?> bytes = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaAssetsTableCompanion(
            id: id,
            fileName: fileName,
            fileType: fileType,
            sizeBytes: sizeBytes,
            folder: folder,
            usageLabel: usageLabel,
            imageUrl: imageUrl,
            bytes: bytes,
            archived: archived,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String fileName,
            required String fileType,
            Value<int> sizeBytes = const Value.absent(),
            required String folder,
            Value<String> usageLabel = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<Uint8List?> bytes = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaAssetsTableCompanion.insert(
            id: id,
            fileName: fileName,
            fileType: fileType,
            sizeBytes: sizeBytes,
            folder: folder,
            usageLabel: usageLabel,
            imageUrl: imageUrl,
            bytes: bytes,
            archived: archived,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MediaAssetsTableTable, MediaAssetEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $MediaAssetsTableTable,
                        MediaAssetEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MediaAssetsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaAssetsTableTable,
    MediaAssetEntity,
    $$MediaAssetsTableTableFilterComposer,
    $$MediaAssetsTableTableOrderingComposer,
    $$MediaAssetsTableTableAnnotationComposer,
    $$MediaAssetsTableTableCreateCompanionBuilder,
    $$MediaAssetsTableTableUpdateCompanionBuilder,
    (
      MediaAssetEntity,
      BaseReferences<_$AppDatabase, $MediaAssetsTableTable, MediaAssetEntity>
    ),
    MediaAssetEntity,
    PrefetchHooks Function()>;
typedef $$RecipesTableTableCreateCompanionBuilder = RecipesTableCompanion
    Function({
  required String id,
  required String code,
  required String name,
  Value<String> version,
  Value<String?> linkedMenuItemId,
  Value<String> linkedMenuItemName,
  Value<String> category,
  Value<String> portion,
  Value<double> targetPrice,
  Value<double> laborCost,
  Value<double> packagingCost,
  Value<String> trialResult,
  Value<int> trainingDone,
  Value<int> trainingTotal,
  Value<String> status,
  Value<String> prepMethod,
  Value<String> allergens,
  Value<String> activeChannels,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$RecipesTableTableUpdateCompanionBuilder = RecipesTableCompanion
    Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<String> version,
  Value<String?> linkedMenuItemId,
  Value<String> linkedMenuItemName,
  Value<String> category,
  Value<String> portion,
  Value<double> targetPrice,
  Value<double> laborCost,
  Value<double> packagingCost,
  Value<String> trialResult,
  Value<int> trainingDone,
  Value<int> trainingTotal,
  Value<String> status,
  Value<String> prepMethod,
  Value<String> allergens,
  Value<String> activeChannels,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$RecipesTableTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTableTable> {
  $$RecipesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get linkedMenuItemId => $composableBuilder(
      column: $table.linkedMenuItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get linkedMenuItemName => $composableBuilder(
      column: $table.linkedMenuItemName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get portion => $composableBuilder(
      column: $table.portion, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetPrice => $composableBuilder(
      column: $table.targetPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get laborCost => $composableBuilder(
      column: $table.laborCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get packagingCost => $composableBuilder(
      column: $table.packagingCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trialResult => $composableBuilder(
      column: $table.trialResult, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainingDone => $composableBuilder(
      column: $table.trainingDone, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainingTotal => $composableBuilder(
      column: $table.trainingTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prepMethod => $composableBuilder(
      column: $table.prepMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get allergens => $composableBuilder(
      column: $table.allergens, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeChannels => $composableBuilder(
      column: $table.activeChannels,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$RecipesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTableTable> {
  $$RecipesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get linkedMenuItemId => $composableBuilder(
      column: $table.linkedMenuItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get linkedMenuItemName => $composableBuilder(
      column: $table.linkedMenuItemName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get portion => $composableBuilder(
      column: $table.portion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetPrice => $composableBuilder(
      column: $table.targetPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get laborCost => $composableBuilder(
      column: $table.laborCost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get packagingCost => $composableBuilder(
      column: $table.packagingCost,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trialResult => $composableBuilder(
      column: $table.trialResult, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainingDone => $composableBuilder(
      column: $table.trainingDone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainingTotal => $composableBuilder(
      column: $table.trainingTotal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prepMethod => $composableBuilder(
      column: $table.prepMethod, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get allergens => $composableBuilder(
      column: $table.allergens, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeChannels => $composableBuilder(
      column: $table.activeChannels,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecipesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTableTable> {
  $$RecipesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get linkedMenuItemId => $composableBuilder(
      column: $table.linkedMenuItemId, builder: (column) => column);

  GeneratedColumn<String> get linkedMenuItemName => $composableBuilder(
      column: $table.linkedMenuItemName, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get portion =>
      $composableBuilder(column: $table.portion, builder: (column) => column);

  GeneratedColumn<double> get targetPrice => $composableBuilder(
      column: $table.targetPrice, builder: (column) => column);

  GeneratedColumn<double> get laborCost =>
      $composableBuilder(column: $table.laborCost, builder: (column) => column);

  GeneratedColumn<double> get packagingCost => $composableBuilder(
      column: $table.packagingCost, builder: (column) => column);

  GeneratedColumn<String> get trialResult => $composableBuilder(
      column: $table.trialResult, builder: (column) => column);

  GeneratedColumn<int> get trainingDone => $composableBuilder(
      column: $table.trainingDone, builder: (column) => column);

  GeneratedColumn<int> get trainingTotal => $composableBuilder(
      column: $table.trainingTotal, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get prepMethod => $composableBuilder(
      column: $table.prepMethod, builder: (column) => column);

  GeneratedColumn<String> get allergens =>
      $composableBuilder(column: $table.allergens, builder: (column) => column);

  GeneratedColumn<String> get activeChannels => $composableBuilder(
      column: $table.activeChannels, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecipesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipesTableTable,
    RecipeEntity,
    $$RecipesTableTableFilterComposer,
    $$RecipesTableTableOrderingComposer,
    $$RecipesTableTableAnnotationComposer,
    $$RecipesTableTableCreateCompanionBuilder,
    $$RecipesTableTableUpdateCompanionBuilder,
    (
      RecipeEntity,
      BaseReferences<_$AppDatabase, $RecipesTableTable, RecipeEntity>
    ),
    RecipeEntity,
    PrefetchHooks Function()> {
  $$RecipesTableTableTableManager(_$AppDatabase db, $RecipesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String?> linkedMenuItemId = const Value.absent(),
            Value<String> linkedMenuItemName = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> portion = const Value.absent(),
            Value<double> targetPrice = const Value.absent(),
            Value<double> laborCost = const Value.absent(),
            Value<double> packagingCost = const Value.absent(),
            Value<String> trialResult = const Value.absent(),
            Value<int> trainingDone = const Value.absent(),
            Value<int> trainingTotal = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> prepMethod = const Value.absent(),
            Value<String> allergens = const Value.absent(),
            Value<String> activeChannels = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipesTableCompanion(
            id: id,
            code: code,
            name: name,
            version: version,
            linkedMenuItemId: linkedMenuItemId,
            linkedMenuItemName: linkedMenuItemName,
            category: category,
            portion: portion,
            targetPrice: targetPrice,
            laborCost: laborCost,
            packagingCost: packagingCost,
            trialResult: trialResult,
            trainingDone: trainingDone,
            trainingTotal: trainingTotal,
            status: status,
            prepMethod: prepMethod,
            allergens: allergens,
            activeChannels: activeChannels,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String code,
            required String name,
            Value<String> version = const Value.absent(),
            Value<String?> linkedMenuItemId = const Value.absent(),
            Value<String> linkedMenuItemName = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> portion = const Value.absent(),
            Value<double> targetPrice = const Value.absent(),
            Value<double> laborCost = const Value.absent(),
            Value<double> packagingCost = const Value.absent(),
            Value<String> trialResult = const Value.absent(),
            Value<int> trainingDone = const Value.absent(),
            Value<int> trainingTotal = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> prepMethod = const Value.absent(),
            Value<String> allergens = const Value.absent(),
            Value<String> activeChannels = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipesTableCompanion.insert(
            id: id,
            code: code,
            name: name,
            version: version,
            linkedMenuItemId: linkedMenuItemId,
            linkedMenuItemName: linkedMenuItemName,
            category: category,
            portion: portion,
            targetPrice: targetPrice,
            laborCost: laborCost,
            packagingCost: packagingCost,
            trialResult: trialResult,
            trainingDone: trainingDone,
            trainingTotal: trainingTotal,
            status: status,
            prepMethod: prepMethod,
            allergens: allergens,
            activeChannels: activeChannels,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RecipesTableTable, RecipeEntity>(table),
                    BaseReferences<_$AppDatabase, $RecipesTableTable,
                        RecipeEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecipesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipesTableTable,
    RecipeEntity,
    $$RecipesTableTableFilterComposer,
    $$RecipesTableTableOrderingComposer,
    $$RecipesTableTableAnnotationComposer,
    $$RecipesTableTableCreateCompanionBuilder,
    $$RecipesTableTableUpdateCompanionBuilder,
    (
      RecipeEntity,
      BaseReferences<_$AppDatabase, $RecipesTableTable, RecipeEntity>
    ),
    RecipeEntity,
    PrefetchHooks Function()>;
typedef $$RecipeLinesTableTableCreateCompanionBuilder
    = RecipeLinesTableCompanion Function({
  Value<int> id,
  required String recipeId,
  Value<String?> materialId,
  required String name,
  required double qty,
  required String unit,
  Value<double> wastagePct,
  Value<double> fallbackUnitCost,
  Value<bool> isKey,
  Value<String> substitute,
});
typedef $$RecipeLinesTableTableUpdateCompanionBuilder
    = RecipeLinesTableCompanion Function({
  Value<int> id,
  Value<String> recipeId,
  Value<String?> materialId,
  Value<String> name,
  Value<double> qty,
  Value<String> unit,
  Value<double> wastagePct,
  Value<double> fallbackUnitCost,
  Value<bool> isKey,
  Value<String> substitute,
});

class $$RecipeLinesTableTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeLinesTableTable> {
  $$RecipeLinesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get wastagePct => $composableBuilder(
      column: $table.wastagePct, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fallbackUnitCost => $composableBuilder(
      column: $table.fallbackUnitCost,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isKey => $composableBuilder(
      column: $table.isKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get substitute => $composableBuilder(
      column: $table.substitute, builder: (column) => ColumnFilters(column));
}

class $$RecipeLinesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeLinesTableTable> {
  $$RecipeLinesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get wastagePct => $composableBuilder(
      column: $table.wastagePct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fallbackUnitCost => $composableBuilder(
      column: $table.fallbackUnitCost,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isKey => $composableBuilder(
      column: $table.isKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get substitute => $composableBuilder(
      column: $table.substitute, builder: (column) => ColumnOrderings(column));
}

class $$RecipeLinesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeLinesTableTable> {
  $$RecipeLinesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recipeId =>
      $composableBuilder(column: $table.recipeId, builder: (column) => column);

  GeneratedColumn<String> get materialId => $composableBuilder(
      column: $table.materialId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get wastagePct => $composableBuilder(
      column: $table.wastagePct, builder: (column) => column);

  GeneratedColumn<double> get fallbackUnitCost => $composableBuilder(
      column: $table.fallbackUnitCost, builder: (column) => column);

  GeneratedColumn<bool> get isKey =>
      $composableBuilder(column: $table.isKey, builder: (column) => column);

  GeneratedColumn<String> get substitute => $composableBuilder(
      column: $table.substitute, builder: (column) => column);
}

class $$RecipeLinesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipeLinesTableTable,
    RecipeLineEntity,
    $$RecipeLinesTableTableFilterComposer,
    $$RecipeLinesTableTableOrderingComposer,
    $$RecipeLinesTableTableAnnotationComposer,
    $$RecipeLinesTableTableCreateCompanionBuilder,
    $$RecipeLinesTableTableUpdateCompanionBuilder,
    (
      RecipeLineEntity,
      BaseReferences<_$AppDatabase, $RecipeLinesTableTable, RecipeLineEntity>
    ),
    RecipeLineEntity,
    PrefetchHooks Function()> {
  $$RecipeLinesTableTableTableManager(
      _$AppDatabase db, $RecipeLinesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeLinesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeLinesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeLinesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> recipeId = const Value.absent(),
            Value<String?> materialId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> qty = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> wastagePct = const Value.absent(),
            Value<double> fallbackUnitCost = const Value.absent(),
            Value<bool> isKey = const Value.absent(),
            Value<String> substitute = const Value.absent(),
          }) =>
              RecipeLinesTableCompanion(
            id: id,
            recipeId: recipeId,
            materialId: materialId,
            name: name,
            qty: qty,
            unit: unit,
            wastagePct: wastagePct,
            fallbackUnitCost: fallbackUnitCost,
            isKey: isKey,
            substitute: substitute,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String recipeId,
            Value<String?> materialId = const Value.absent(),
            required String name,
            required double qty,
            required String unit,
            Value<double> wastagePct = const Value.absent(),
            Value<double> fallbackUnitCost = const Value.absent(),
            Value<bool> isKey = const Value.absent(),
            Value<String> substitute = const Value.absent(),
          }) =>
              RecipeLinesTableCompanion.insert(
            id: id,
            recipeId: recipeId,
            materialId: materialId,
            name: name,
            qty: qty,
            unit: unit,
            wastagePct: wastagePct,
            fallbackUnitCost: fallbackUnitCost,
            isKey: isKey,
            substitute: substitute,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RecipeLinesTableTable, RecipeLineEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $RecipeLinesTableTable,
                        RecipeLineEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecipeLinesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipeLinesTableTable,
    RecipeLineEntity,
    $$RecipeLinesTableTableFilterComposer,
    $$RecipeLinesTableTableOrderingComposer,
    $$RecipeLinesTableTableAnnotationComposer,
    $$RecipeLinesTableTableCreateCompanionBuilder,
    $$RecipeLinesTableTableUpdateCompanionBuilder,
    (
      RecipeLineEntity,
      BaseReferences<_$AppDatabase, $RecipeLinesTableTable, RecipeLineEntity>
    ),
    RecipeLineEntity,
    PrefetchHooks Function()>;
typedef $$DeliveriesTableTableCreateCompanionBuilder = DeliveriesTableCompanion
    Function({
  required String id,
  required String orderId,
  required String merchant,
  Value<String?> riderName,
  required String status,
  Value<int?> etaMinutes,
  Value<double> distanceKm,
  Value<String> customerName,
  Value<String> address,
  Value<DateTime?> promisedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DeliveriesTableTableUpdateCompanionBuilder = DeliveriesTableCompanion
    Function({
  Value<String> id,
  Value<String> orderId,
  Value<String> merchant,
  Value<String?> riderName,
  Value<String> status,
  Value<int?> etaMinutes,
  Value<double> distanceKm,
  Value<String> customerName,
  Value<String> address,
  Value<DateTime?> promisedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DeliveriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $DeliveriesTableTable> {
  $$DeliveriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get riderName => $composableBuilder(
      column: $table.riderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get etaMinutes => $composableBuilder(
      column: $table.etaMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceKm => $composableBuilder(
      column: $table.distanceKm, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get promisedAt => $composableBuilder(
      column: $table.promisedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DeliveriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DeliveriesTableTable> {
  $$DeliveriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get riderName => $composableBuilder(
      column: $table.riderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get etaMinutes => $composableBuilder(
      column: $table.etaMinutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceKm => $composableBuilder(
      column: $table.distanceKm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get promisedAt => $composableBuilder(
      column: $table.promisedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DeliveriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeliveriesTableTable> {
  $$DeliveriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get riderName =>
      $composableBuilder(column: $table.riderName, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get etaMinutes => $composableBuilder(
      column: $table.etaMinutes, builder: (column) => column);

  GeneratedColumn<double> get distanceKm => $composableBuilder(
      column: $table.distanceKm, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<DateTime> get promisedAt => $composableBuilder(
      column: $table.promisedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeliveriesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeliveriesTableTable,
    DeliveryEntity,
    $$DeliveriesTableTableFilterComposer,
    $$DeliveriesTableTableOrderingComposer,
    $$DeliveriesTableTableAnnotationComposer,
    $$DeliveriesTableTableCreateCompanionBuilder,
    $$DeliveriesTableTableUpdateCompanionBuilder,
    (
      DeliveryEntity,
      BaseReferences<_$AppDatabase, $DeliveriesTableTable, DeliveryEntity>
    ),
    DeliveryEntity,
    PrefetchHooks Function()> {
  $$DeliveriesTableTableTableManager(
      _$AppDatabase db, $DeliveriesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> orderId = const Value.absent(),
            Value<String> merchant = const Value.absent(),
            Value<String?> riderName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> etaMinutes = const Value.absent(),
            Value<double> distanceKm = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<String> address = const Value.absent(),
            Value<DateTime?> promisedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeliveriesTableCompanion(
            id: id,
            orderId: orderId,
            merchant: merchant,
            riderName: riderName,
            status: status,
            etaMinutes: etaMinutes,
            distanceKm: distanceKm,
            customerName: customerName,
            address: address,
            promisedAt: promisedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String orderId,
            required String merchant,
            Value<String?> riderName = const Value.absent(),
            required String status,
            Value<int?> etaMinutes = const Value.absent(),
            Value<double> distanceKm = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<String> address = const Value.absent(),
            Value<DateTime?> promisedAt = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DeliveriesTableCompanion.insert(
            id: id,
            orderId: orderId,
            merchant: merchant,
            riderName: riderName,
            status: status,
            etaMinutes: etaMinutes,
            distanceKm: distanceKm,
            customerName: customerName,
            address: address,
            promisedAt: promisedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DeliveriesTableTable, DeliveryEntity>(table),
                    BaseReferences<_$AppDatabase, $DeliveriesTableTable,
                        DeliveryEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeliveriesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeliveriesTableTable,
    DeliveryEntity,
    $$DeliveriesTableTableFilterComposer,
    $$DeliveriesTableTableOrderingComposer,
    $$DeliveriesTableTableAnnotationComposer,
    $$DeliveriesTableTableCreateCompanionBuilder,
    $$DeliveriesTableTableUpdateCompanionBuilder,
    (
      DeliveryEntity,
      BaseReferences<_$AppDatabase, $DeliveriesTableTable, DeliveryEntity>
    ),
    DeliveryEntity,
    PrefetchHooks Function()>;
typedef $$ReservationsTableTableCreateCompanionBuilder
    = ReservationsTableCompanion Function({
  required String id,
  required String guestName,
  required String phone,
  Value<String> email,
  required int guests,
  required DateTime scheduledAt,
  required String status,
  Value<String?> tableId,
  Value<String> notes,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ReservationsTableTableUpdateCompanionBuilder
    = ReservationsTableCompanion Function({
  Value<String> id,
  Value<String> guestName,
  Value<String> phone,
  Value<String> email,
  Value<int> guests,
  Value<DateTime> scheduledAt,
  Value<String> status,
  Value<String?> tableId,
  Value<String> notes,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ReservationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReservationsTableTable> {
  $$ReservationsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestName => $composableBuilder(
      column: $table.guestName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get guests => $composableBuilder(
      column: $table.guests, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableId => $composableBuilder(
      column: $table.tableId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ReservationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReservationsTableTable> {
  $$ReservationsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestName => $composableBuilder(
      column: $table.guestName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get guests => $composableBuilder(
      column: $table.guests, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableId => $composableBuilder(
      column: $table.tableId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ReservationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReservationsTableTable> {
  $$ReservationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guestName =>
      $composableBuilder(column: $table.guestName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get guests =>
      $composableBuilder(column: $table.guests, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get tableId =>
      $composableBuilder(column: $table.tableId, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReservationsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReservationsTableTable,
    ReservationEntity,
    $$ReservationsTableTableFilterComposer,
    $$ReservationsTableTableOrderingComposer,
    $$ReservationsTableTableAnnotationComposer,
    $$ReservationsTableTableCreateCompanionBuilder,
    $$ReservationsTableTableUpdateCompanionBuilder,
    (
      ReservationEntity,
      BaseReferences<_$AppDatabase, $ReservationsTableTable, ReservationEntity>
    ),
    ReservationEntity,
    PrefetchHooks Function()> {
  $$ReservationsTableTableTableManager(
      _$AppDatabase db, $ReservationsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReservationsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReservationsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReservationsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> guestName = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<int> guests = const Value.absent(),
            Value<DateTime> scheduledAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> tableId = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReservationsTableCompanion(
            id: id,
            guestName: guestName,
            phone: phone,
            email: email,
            guests: guests,
            scheduledAt: scheduledAt,
            status: status,
            tableId: tableId,
            notes: notes,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String guestName,
            required String phone,
            Value<String> email = const Value.absent(),
            required int guests,
            required DateTime scheduledAt,
            required String status,
            Value<String?> tableId = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReservationsTableCompanion.insert(
            id: id,
            guestName: guestName,
            phone: phone,
            email: email,
            guests: guests,
            scheduledAt: scheduledAt,
            status: status,
            tableId: tableId,
            notes: notes,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ReservationsTableTable, ReservationEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $ReservationsTableTable,
                        ReservationEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReservationsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReservationsTableTable,
    ReservationEntity,
    $$ReservationsTableTableFilterComposer,
    $$ReservationsTableTableOrderingComposer,
    $$ReservationsTableTableAnnotationComposer,
    $$ReservationsTableTableCreateCompanionBuilder,
    $$ReservationsTableTableUpdateCompanionBuilder,
    (
      ReservationEntity,
      BaseReferences<_$AppDatabase, $ReservationsTableTable, ReservationEntity>
    ),
    ReservationEntity,
    PrefetchHooks Function()>;
typedef $$QrCodesTableTableCreateCompanionBuilder = QrCodesTableCompanion
    Function({
  required String tableId,
  Value<bool> enabled,
  required String token,
  Value<DateTime?> lastScannedAt,
  Value<int> rowid,
});
typedef $$QrCodesTableTableUpdateCompanionBuilder = QrCodesTableCompanion
    Function({
  Value<String> tableId,
  Value<bool> enabled,
  Value<String> token,
  Value<DateTime?> lastScannedAt,
  Value<int> rowid,
});

class $$QrCodesTableTableFilterComposer
    extends Composer<_$AppDatabase, $QrCodesTableTable> {
  $$QrCodesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tableId => $composableBuilder(
      column: $table.tableId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get token => $composableBuilder(
      column: $table.token, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastScannedAt => $composableBuilder(
      column: $table.lastScannedAt, builder: (column) => ColumnFilters(column));
}

class $$QrCodesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $QrCodesTableTable> {
  $$QrCodesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tableId => $composableBuilder(
      column: $table.tableId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get token => $composableBuilder(
      column: $table.token, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastScannedAt => $composableBuilder(
      column: $table.lastScannedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$QrCodesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $QrCodesTableTable> {
  $$QrCodesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tableId =>
      $composableBuilder(column: $table.tableId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScannedAt => $composableBuilder(
      column: $table.lastScannedAt, builder: (column) => column);
}

class $$QrCodesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QrCodesTableTable,
    QrCodeEntity,
    $$QrCodesTableTableFilterComposer,
    $$QrCodesTableTableOrderingComposer,
    $$QrCodesTableTableAnnotationComposer,
    $$QrCodesTableTableCreateCompanionBuilder,
    $$QrCodesTableTableUpdateCompanionBuilder,
    (
      QrCodeEntity,
      BaseReferences<_$AppDatabase, $QrCodesTableTable, QrCodeEntity>
    ),
    QrCodeEntity,
    PrefetchHooks Function()> {
  $$QrCodesTableTableTableManager(_$AppDatabase db, $QrCodesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QrCodesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QrCodesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QrCodesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tableId = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<String> token = const Value.absent(),
            Value<DateTime?> lastScannedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QrCodesTableCompanion(
            tableId: tableId,
            enabled: enabled,
            token: token,
            lastScannedAt: lastScannedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tableId,
            Value<bool> enabled = const Value.absent(),
            required String token,
            Value<DateTime?> lastScannedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QrCodesTableCompanion.insert(
            tableId: tableId,
            enabled: enabled,
            token: token,
            lastScannedAt: lastScannedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QrCodesTableTable, QrCodeEntity>(table),
                    BaseReferences<_$AppDatabase, $QrCodesTableTable,
                        QrCodeEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QrCodesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QrCodesTableTable,
    QrCodeEntity,
    $$QrCodesTableTableFilterComposer,
    $$QrCodesTableTableOrderingComposer,
    $$QrCodesTableTableAnnotationComposer,
    $$QrCodesTableTableCreateCompanionBuilder,
    $$QrCodesTableTableUpdateCompanionBuilder,
    (
      QrCodeEntity,
      BaseReferences<_$AppDatabase, $QrCodesTableTable, QrCodeEntity>
    ),
    QrCodeEntity,
    PrefetchHooks Function()>;
typedef $$QrSessionsTableTableCreateCompanionBuilder = QrSessionsTableCompanion
    Function({
  required String id,
  required String tableLabel,
  Value<int> guests,
  required DateTime startedAt,
  required String status,
  Value<String?> orderId,
  Value<int> itemCount,
  Value<int> totalMinor,
  Value<DateTime?> closedAt,
  Value<int> rowid,
});
typedef $$QrSessionsTableTableUpdateCompanionBuilder = QrSessionsTableCompanion
    Function({
  Value<String> id,
  Value<String> tableLabel,
  Value<int> guests,
  Value<DateTime> startedAt,
  Value<String> status,
  Value<String?> orderId,
  Value<int> itemCount,
  Value<int> totalMinor,
  Value<DateTime?> closedAt,
  Value<int> rowid,
});

class $$QrSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $QrSessionsTableTable> {
  $$QrSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableLabel => $composableBuilder(
      column: $table.tableLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get guests => $composableBuilder(
      column: $table.guests, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
      column: $table.closedAt, builder: (column) => ColumnFilters(column));
}

class $$QrSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $QrSessionsTableTable> {
  $$QrSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableLabel => $composableBuilder(
      column: $table.tableLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get guests => $composableBuilder(
      column: $table.guests, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
      column: $table.closedAt, builder: (column) => ColumnOrderings(column));
}

class $$QrSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $QrSessionsTableTable> {
  $$QrSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tableLabel => $composableBuilder(
      column: $table.tableLabel, builder: (column) => column);

  GeneratedColumn<int> get guests =>
      $composableBuilder(column: $table.guests, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);
}

class $$QrSessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QrSessionsTableTable,
    QrSessionEntity,
    $$QrSessionsTableTableFilterComposer,
    $$QrSessionsTableTableOrderingComposer,
    $$QrSessionsTableTableAnnotationComposer,
    $$QrSessionsTableTableCreateCompanionBuilder,
    $$QrSessionsTableTableUpdateCompanionBuilder,
    (
      QrSessionEntity,
      BaseReferences<_$AppDatabase, $QrSessionsTableTable, QrSessionEntity>
    ),
    QrSessionEntity,
    PrefetchHooks Function()> {
  $$QrSessionsTableTableTableManager(
      _$AppDatabase db, $QrSessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QrSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QrSessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QrSessionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tableLabel = const Value.absent(),
            Value<int> guests = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> orderId = const Value.absent(),
            Value<int> itemCount = const Value.absent(),
            Value<int> totalMinor = const Value.absent(),
            Value<DateTime?> closedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QrSessionsTableCompanion(
            id: id,
            tableLabel: tableLabel,
            guests: guests,
            startedAt: startedAt,
            status: status,
            orderId: orderId,
            itemCount: itemCount,
            totalMinor: totalMinor,
            closedAt: closedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tableLabel,
            Value<int> guests = const Value.absent(),
            required DateTime startedAt,
            required String status,
            Value<String?> orderId = const Value.absent(),
            Value<int> itemCount = const Value.absent(),
            Value<int> totalMinor = const Value.absent(),
            Value<DateTime?> closedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QrSessionsTableCompanion.insert(
            id: id,
            tableLabel: tableLabel,
            guests: guests,
            startedAt: startedAt,
            status: status,
            orderId: orderId,
            itemCount: itemCount,
            totalMinor: totalMinor,
            closedAt: closedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QrSessionsTableTable, QrSessionEntity>(table),
                    BaseReferences<_$AppDatabase, $QrSessionsTableTable,
                        QrSessionEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QrSessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QrSessionsTableTable,
    QrSessionEntity,
    $$QrSessionsTableTableFilterComposer,
    $$QrSessionsTableTableOrderingComposer,
    $$QrSessionsTableTableAnnotationComposer,
    $$QrSessionsTableTableCreateCompanionBuilder,
    $$QrSessionsTableTableUpdateCompanionBuilder,
    (
      QrSessionEntity,
      BaseReferences<_$AppDatabase, $QrSessionsTableTable, QrSessionEntity>
    ),
    QrSessionEntity,
    PrefetchHooks Function()>;
typedef $$SyncRowStatesTableCreateCompanionBuilder = SyncRowStatesCompanion
    Function({
  required String localTable,
  required String rowKey,
  required String keyJson,
  required String rowHash,
  Value<String?> serverVersion,
  Value<String> status,
  Value<String?> rejectedHash,
  Value<String?> lastError,
  required DateTime syncedAt,
  Value<int> rowid,
});
typedef $$SyncRowStatesTableUpdateCompanionBuilder = SyncRowStatesCompanion
    Function({
  Value<String> localTable,
  Value<String> rowKey,
  Value<String> keyJson,
  Value<String> rowHash,
  Value<String?> serverVersion,
  Value<String> status,
  Value<String?> rejectedHash,
  Value<String?> lastError,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$SyncRowStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRowStatesTable> {
  $$SyncRowStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localTable => $composableBuilder(
      column: $table.localTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rowKey => $composableBuilder(
      column: $table.rowKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get keyJson => $composableBuilder(
      column: $table.keyJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rowHash => $composableBuilder(
      column: $table.rowHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverVersion => $composableBuilder(
      column: $table.serverVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rejectedHash => $composableBuilder(
      column: $table.rejectedHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncRowStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRowStatesTable> {
  $$SyncRowStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localTable => $composableBuilder(
      column: $table.localTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rowKey => $composableBuilder(
      column: $table.rowKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get keyJson => $composableBuilder(
      column: $table.keyJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rowHash => $composableBuilder(
      column: $table.rowHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverVersion => $composableBuilder(
      column: $table.serverVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rejectedHash => $composableBuilder(
      column: $table.rejectedHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncRowStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRowStatesTable> {
  $$SyncRowStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localTable => $composableBuilder(
      column: $table.localTable, builder: (column) => column);

  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<String> get keyJson =>
      $composableBuilder(column: $table.keyJson, builder: (column) => column);

  GeneratedColumn<String> get rowHash =>
      $composableBuilder(column: $table.rowHash, builder: (column) => column);

  GeneratedColumn<String> get serverVersion => $composableBuilder(
      column: $table.serverVersion, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rejectedHash => $composableBuilder(
      column: $table.rejectedHash, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncRowStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncRowStatesTable,
    SyncRowStateRow,
    $$SyncRowStatesTableFilterComposer,
    $$SyncRowStatesTableOrderingComposer,
    $$SyncRowStatesTableAnnotationComposer,
    $$SyncRowStatesTableCreateCompanionBuilder,
    $$SyncRowStatesTableUpdateCompanionBuilder,
    (
      SyncRowStateRow,
      BaseReferences<_$AppDatabase, $SyncRowStatesTable, SyncRowStateRow>
    ),
    SyncRowStateRow,
    PrefetchHooks Function()> {
  $$SyncRowStatesTableTableManager(_$AppDatabase db, $SyncRowStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRowStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRowStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRowStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localTable = const Value.absent(),
            Value<String> rowKey = const Value.absent(),
            Value<String> keyJson = const Value.absent(),
            Value<String> rowHash = const Value.absent(),
            Value<String?> serverVersion = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> rejectedHash = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncRowStatesCompanion(
            localTable: localTable,
            rowKey: rowKey,
            keyJson: keyJson,
            rowHash: rowHash,
            serverVersion: serverVersion,
            status: status,
            rejectedHash: rejectedHash,
            lastError: lastError,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localTable,
            required String rowKey,
            required String keyJson,
            required String rowHash,
            Value<String?> serverVersion = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> rejectedHash = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required DateTime syncedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncRowStatesCompanion.insert(
            localTable: localTable,
            rowKey: rowKey,
            keyJson: keyJson,
            rowHash: rowHash,
            serverVersion: serverVersion,
            status: status,
            rejectedHash: rejectedHash,
            lastError: lastError,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncRowStatesTable, SyncRowStateRow>(table),
                    BaseReferences<_$AppDatabase, $SyncRowStatesTable,
                        SyncRowStateRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncRowStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncRowStatesTable,
    SyncRowStateRow,
    $$SyncRowStatesTableFilterComposer,
    $$SyncRowStatesTableOrderingComposer,
    $$SyncRowStatesTableAnnotationComposer,
    $$SyncRowStatesTableCreateCompanionBuilder,
    $$SyncRowStatesTableUpdateCompanionBuilder,
    (
      SyncRowStateRow,
      BaseReferences<_$AppDatabase, $SyncRowStatesTable, SyncRowStateRow>
    ),
    SyncRowStateRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
  $$OrderLinesTableTableManager get orderLines =>
      $$OrderLinesTableTableManager(_db, _db.orderLines);
  $$PendingUploadIntentsTableTableManager get pendingUploadIntents =>
      $$PendingUploadIntentsTableTableManager(_db, _db.pendingUploadIntents);
  $$KitchenTicketsTableTableManager get kitchenTickets =>
      $$KitchenTicketsTableTableManager(_db, _db.kitchenTickets);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db, _db.shifts);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$DeviceSessionsTableTableManager get deviceSessions =>
      $$DeviceSessionsTableTableManager(_db, _db.deviceSessions);
  $$RestaurantTablesTableTableManager get restaurantTables =>
      $$RestaurantTablesTableTableManager(_db, _db.restaurantTables);
  $$AllOrdersTableTableTableManager get allOrdersTable =>
      $$AllOrdersTableTableTableManager(_db, _db.allOrdersTable);
  $$MenuCategoriesTableTableTableManager get menuCategoriesTable =>
      $$MenuCategoriesTableTableTableManager(_db, _db.menuCategoriesTable);
  $$MenuItemsTableTableTableManager get menuItemsTable =>
      $$MenuItemsTableTableTableManager(_db, _db.menuItemsTable);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
  $$RawMaterialsTableTableTableManager get rawMaterialsTable =>
      $$RawMaterialsTableTableTableManager(_db, _db.rawMaterialsTable);
  $$SuppliersTableTableTableManager get suppliersTable =>
      $$SuppliersTableTableTableManager(_db, _db.suppliersTable);
  $$SupplierPricesTableTableTableManager get supplierPricesTable =>
      $$SupplierPricesTableTableTableManager(_db, _db.supplierPricesTable);
  $$PurchaseOrdersTableTableTableManager get purchaseOrdersTable =>
      $$PurchaseOrdersTableTableTableManager(_db, _db.purchaseOrdersTable);
  $$PurchaseOrderLinesTableTableTableManager get purchaseOrderLinesTable =>
      $$PurchaseOrderLinesTableTableTableManager(
          _db, _db.purchaseOrderLinesTable);
  $$GoodsReceiptsTableTableTableManager get goodsReceiptsTable =>
      $$GoodsReceiptsTableTableTableManager(_db, _db.goodsReceiptsTable);
  $$StockMovementsTableTableTableManager get stockMovementsTable =>
      $$StockMovementsTableTableTableManager(_db, _db.stockMovementsTable);
  $$OffersTableTableTableManager get offersTable =>
      $$OffersTableTableTableManager(_db, _db.offersTable);
  $$MediaAssetsTableTableTableManager get mediaAssetsTable =>
      $$MediaAssetsTableTableTableManager(_db, _db.mediaAssetsTable);
  $$RecipesTableTableTableManager get recipesTable =>
      $$RecipesTableTableTableManager(_db, _db.recipesTable);
  $$RecipeLinesTableTableTableManager get recipeLinesTable =>
      $$RecipeLinesTableTableTableManager(_db, _db.recipeLinesTable);
  $$DeliveriesTableTableTableManager get deliveriesTable =>
      $$DeliveriesTableTableTableManager(_db, _db.deliveriesTable);
  $$ReservationsTableTableTableManager get reservationsTable =>
      $$ReservationsTableTableTableManager(_db, _db.reservationsTable);
  $$QrCodesTableTableTableManager get qrCodesTable =>
      $$QrCodesTableTableTableManager(_db, _db.qrCodesTable);
  $$QrSessionsTableTableTableManager get qrSessionsTable =>
      $$QrSessionsTableTableTableManager(_db, _db.qrSessionsTable);
  $$SyncRowStatesTableTableManager get syncRowStates =>
      $$SyncRowStatesTableTableManager(_db, _db.syncRowStates);
}
